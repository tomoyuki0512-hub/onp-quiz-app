import Flutter
import Photos
import UIKit

public class BurstPhotoPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.photo_deleter/burst",
            binaryMessenger: registrar.messenger()
        )
        let instance = BurstPhotoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "getBurstGroups":
            getBurstGroups(result: result)
        case "getAssetThumbnail":
            guard let args = call.arguments as? [String: Any],
                  let assetId = args["assetId"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "assetId required", details: nil))
                return
            }
            let size = args["size"] as? Int ?? 300
            getAssetThumbnail(assetId: assetId, size: size, result: result)
        case "deleteAssets":
            guard let args = call.arguments as? [String: Any],
                  let ids = args["assetIds"] as? [String] else {
                result(FlutterError(code: "BAD_ARGS", message: "assetIds required", details: nil))
                return
            }
            deleteAssets(localIds: ids, result: result)
        case "saveAssetsAsCopies":
            guard let args = call.arguments as? [String: Any],
                  let ids = args["assetIds"] as? [String] else {
                result(FlutterError(code: "BAD_ARGS", message: "assetIds required", details: nil))
                return
            }
            saveAssetsAsCopies(localIds: ids, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helper

    // PHAsset.fetchAssets(withLocalIdentifiers:) ignores includeAllBurstAssets,
    // so non-representative burst frames are missed. Enumerate all and filter instead.
    private func fetchAssets(matchingIds ids: Set<String>) -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.includeAllBurstAssets = true
        var matched: [PHAsset] = []
        PHAsset.fetchAssets(with: opts).enumerateObjects { asset, _, _ in
            if ids.contains(asset.localIdentifier) { matched.append(asset) }
        }
        return matched
    }

    // MARK: - Permission

    private func requestPermission(result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:    result("authorized")
                    case .limited:       result("limited")
                    case .denied:        result("denied")
                    case .restricted:    result("restricted")
                    case .notDetermined: result("notDetermined")
                    @unknown default:    result("unknown")
                    }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:    result("authorized")
                    case .limited:       result("limited")
                    case .denied:        result("denied")
                    case .restricted:    result("restricted")
                    case .notDetermined: result("notDetermined")
                    @unknown default:    result("unknown")
                    }
                }
            }
        }
    }

    // MARK: - Get Burst Groups

    private func getBurstGroups(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var groups: [String: [PHAsset]] = [:]

            let opts = PHFetchOptions()
            opts.includeAllBurstAssets = true
            PHAsset.fetchAssets(with: opts).enumerateObjects { asset, _, _ in
                guard let burstId = asset.burstIdentifier else { return }
                if groups[burstId] == nil { groups[burstId] = [] }
                groups[burstId]!.append(asset)
            }

            let payload: [[String: Any]] = groups.compactMap { (burstId, assets) in
                guard assets.count >= 2 else { return nil }
                let rep = assets.first(where: { $0.representsBurst }) ?? assets.first!
                var dict: [String: Any] = [
                    "burstId": burstId,
                    "assetIds": assets.map { $0.localIdentifier },
                    "count": assets.count,
                    "representativeId": rep.localIdentifier,
                ]
                if let ts = rep.creationDate {
                    dict["createdAt"] = Int(ts.timeIntervalSince1970)
                }
                if let loc = rep.location {
                    dict["latitude"] = loc.coordinate.latitude
                    dict["longitude"] = loc.coordinate.longitude
                }
                return dict
            }.sorted {
                ($0["createdAt"] as? Int ?? 0) < ($1["createdAt"] as? Int ?? 0)
            }

            DispatchQueue.main.async { result(payload) }
        }
    }

    // MARK: - Get Asset Thumbnail

    private func getAssetThumbnail(assetId: String, size: Int, result: @escaping FlutterResult) {
        guard let asset = fetchAssets(matchingIds: [assetId]).first else {
            result(nil)
            return
        }

        let manager = PHImageManager.default()
        let targetSize = CGSize(width: CGFloat(size), height: CGFloat(size))
        let reqOpts = PHImageRequestOptions()
        reqOpts.deliveryMode = .highQualityFormat
        reqOpts.isNetworkAccessAllowed = true

        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: reqOpts) { image, _ in
            guard let image = image, let data = image.jpegData(compressionQuality: 0.85) else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: data))
            }
        }
    }

    // MARK: - Save Assets As Copies

    // 選択したバーストフレームを通常の独立した写真としてライブラリに保存する。
    // 原本の画像データをそのまま使うためメタデータ（撮影日時・位置情報）が保持される。
    private func saveAssetsAsCopies(localIds: [String], result: @escaping FlutterResult) {
        let assets = fetchAssets(matchingIds: Set(localIds))
        guard !assets.isEmpty else { result(true); return }

        let group = DispatchGroup()
        var saveFailed = false

        for asset in assets {
            group.enter()
            let reqOpts = PHImageRequestOptions()
            reqOpts.deliveryMode = .highQualityFormat
            reqOpts.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset, options: reqOpts
            ) { data, _, _, _ in
                guard let data = data else {
                    saveFailed = true
                    group.leave()
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: data, options: nil)
                }) { success, _ in
                    if !success { saveFailed = true }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if saveFailed {
                result(FlutterError(code: "SAVE_FAILED", message: "写真の保存に失敗しました", details: nil))
            } else {
                result(true)
            }
        }
    }

    // MARK: - Delete Assets

    private func deleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let assets = fetchAssets(matchingIds: Set(localIds))
        guard !assets.isEmpty else { result(true); return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error?.localizedDescription ?? "削除に失敗しました",
                        details: nil
                    ))
                }
            }
        }
    }
}
