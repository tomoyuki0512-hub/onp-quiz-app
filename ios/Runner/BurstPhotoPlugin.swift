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
        case "deleteAssets":
            guard let args = call.arguments as? [String: Any],
                  let ids = args["assetIds"] as? [String] else {
                result(FlutterError(code: "BAD_ARGS", message: "assetIds が必要です", details: nil))
                return
            }
            deleteAssets(localIds: ids, result: result)
        case "permanentlyDeleteAssets":
            guard let args = call.arguments as? [String: Any],
                  let ids = args["assetIds"] as? [String] else {
                result(FlutterError(code: "BAD_ARGS", message: "assetIds が必要です", details: nil))
                return
            }
            permanentlyDeleteAssets(localIds: ids, result: result)
        case "getAssetData":
            guard let args = call.arguments as? [String: Any],
                  let assetId = args["assetId"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "assetId が必要です", details: nil))
                return
            }
            let size = args["size"] as? Int ?? 1080
            getAssetData(assetId: assetId, size: size, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
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

    // MARK: - Fetch Burst Groups

    private func getBurstGroups(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allGroups: [String: [PHAsset]] = [:]

            let options = PHFetchOptions()
            options.includeAllBurstAssets = true
            let fetchResult = PHAsset.fetchAssets(with: options)

            fetchResult.enumerateObjects { asset, _, _ in
                guard let burstId = asset.burstIdentifier else { return }
                if allGroups[burstId] == nil {
                    allGroups[burstId] = []
                }
                allGroups[burstId]!.append(asset)
            }

            let payload: [[String: Any]] = allGroups.compactMap { (burstId, assets) in
                guard assets.count >= 2 else { return nil }
                let assetIds = assets.map { $0.localIdentifier }
                let representative = assets.first(where: { $0.representsBurst }) ?? assets.first
                let bestPickId = representative?.localIdentifier
                let createdAt = representative?.creationDate.map { Int($0.timeIntervalSince1970) }
                return [
                    "burstId": burstId,
                    "assetIds": assetIds,
                    "bestPickId": bestPickId as Any,
                    "count": assets.count,
                    "isRecentlyDeleted": false,
                    "createdAt": createdAt as Any
                ]
            }.sorted {
                let a = $0["createdAt"] as? Int ?? 0
                let b = $1["createdAt"] as? Int ?? 0
                return a < b
            }

            DispatchQueue.main.async {
                result(payload)
            }
        }
    }

    // MARK: - Delete (→ 最近削除した項目へ移動)

    private func deleteAssets(localIds: [String], result: @escaping FlutterResult) {
        // includeAllBurstAssets=true が必須:
        // バーストの代表写真以外はデフォルトで hidden 扱いのため nil オプションでは 0件になる
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: options)
        guard fetchResult.count > 0 else {
            result(true)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error?.localizedDescription ?? "不明なエラー",
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Permanently Delete (最近削除した項目を経由して完全削除)

    private func permanentlyDeleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: options)
        guard fetchResult.count > 0 else {
            result(true)
            return
        }

        // Step 1: 通常削除 → 最近削除した項目へ移動
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }) { success, error in
            guard success else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error?.localizedDescription ?? "不明なエラー",
                        details: nil
                    ))
                }
                return
            }

            // Step 2: 最近削除した項目から完全削除
            // PHAssetCollectionSubtype.smartAlbumRecentlyDeleted は iOS 18.5 SDK から
            // 削除されたが rawValue=206 でアルバム自体には引き続きアクセス可能
            guard let rdSubtype = PHAssetCollectionSubtype(rawValue: 206) else {
                DispatchQueue.main.async { result(true) }
                return
            }
            let rdCollections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: rdSubtype, options: nil
            )
            guard rdCollections.count > 0 else {
                // 最近削除した項目にアクセス不可 → 通常削除のみで完了
                DispatchQueue.main.async { result(true) }
                return
            }

            // step 1 後は localIdentifier でメインライブラリから検索しても 0 件になるため
            // 最近削除したアルバム内を predicate でフィルタして取得する
            let rdCollection = rdCollections.firstObject!
            let rdOptions = PHFetchOptions()
            rdOptions.includeAllBurstAssets = true
            rdOptions.predicate = NSPredicate(format: "localIdentifier IN %@", localIds)
            let rdAssets = PHAsset.fetchAssets(in: rdCollection, options: rdOptions)
            guard rdAssets.count > 0 else {
                DispatchQueue.main.async { result(true) }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(rdAssets)
            }) { _, _ in
                DispatchQueue.main.async { result(true) }
            }
        }
    }

    // MARK: - Get Asset Data (バースト写真含む全アセットのサムネイル＋メタデータ取得)

    private func getAssetData(assetId: String, size: Int, result: @escaping FlutterResult) {
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: options)
        guard let asset = fetchResult.firstObject else {
            result(nil)
            return
        }

        let createdAt = asset.creationDate.map { Int($0.timeIntervalSince1970) }
        let lat = asset.location?.coordinate.latitude
        let lng = asset.location?.coordinate.longitude

        let manager = PHImageManager.default()
        let targetSize = CGSize(width: CGFloat(size), height: CGFloat(size))
        let reqOptions = PHImageRequestOptions()
        reqOptions.deliveryMode = .highQualityFormat
        reqOptions.isNetworkAccessAllowed = true

        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: reqOptions) { image, _ in
            guard let image = image, let data = image.jpegData(compressionQuality: 0.92) else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            var info: [String: Any] = [
                "thumbnailData": FlutterStandardTypedData(bytes: data)
            ]
            if let createdAt = createdAt { info["createdAt"] = createdAt }
            if let lat = lat, let lng = lng {
                info["latitude"] = lat
                info["longitude"] = lng
            }
            DispatchQueue.main.async { result(info) }
        }
    }
}
