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
        case "emptyRecentlyDeleted":
            emptyRecentlyDeleted(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Common Helper

    // PHAsset.fetchAssets(withLocalIdentifiers:options:) ignores includeAllBurstAssets,
    // so non-representative burst frames can't be found that way.
    // This helper fetches all assets with the flag enabled, then filters by ID.
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

    // MARK: - Fetch Burst Groups

    private func getBurstGroups(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allGroups: [String: [PHAsset]] = [:]

            let options = PHFetchOptions()
            options.includeAllBurstAssets = true
            PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
                guard let burstId = asset.burstIdentifier else { return }
                if allGroups[burstId] == nil { allGroups[burstId] = [] }
                allGroups[burstId]!.append(asset)
            }

            let payload: [[String: Any]] = allGroups.compactMap { (burstId, assets) in
                guard assets.count >= 2 else { return nil }
                let representative = assets.first(where: { $0.representsBurst }) ?? assets.first
                return [
                    "burstId": burstId,
                    "assetIds": assets.map { $0.localIdentifier },
                    "bestPickId": representative?.localIdentifier as Any,
                    "count": assets.count,
                    "isRecentlyDeleted": false,
                    "createdAt": representative?.creationDate.map { Int($0.timeIntervalSince1970) } as Any
                ]
            }.sorted {
                let a = $0["createdAt"] as? Int ?? 0
                let b = $1["createdAt"] as? Int ?? 0
                return a < b
            }

            DispatchQueue.main.async { result(payload) }
        }
    }

    // MARK: - Delete (→ 最近削除した項目へ移動)

    private func deleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let assetsToDelete = fetchAssets(matchingIds: Set(localIds))
        guard !assetsToDelete.isEmpty else { result(true); return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
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

    // MARK: - Find Recently Deleted Album

    // PHAssetCollectionSubtype.smartAlbumRecentlyDeleted is not in the public SDK.
    // rawValue 1000000201 is the private constant; localized title is a fallback.
    // (rawValue 206 is smartAlbumRecentlyAdded — not Recently Deleted.)
    private func findRecentlyDeletedCollection() -> PHAssetCollection? {
        let all = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .any, options: nil
        )
        let knownTitles: Set<String> = [
            "Recently Deleted",
            "最近削除した項目",
            "최근에 삭제된 항목",
            "最近删除",
            "最近刪除",
            "Suppressions récentes",
            "Zuletzt gelöscht",
            "Eliminados recientemente",
            "Eliminados recentemente",
            "Eliminati di recente",
            "Verwijderde objecten",
            "Senast borttagna",
            "Nyligt slettet",
            "Nylig slettet",
            "Az utóbbi időben törölt elemek",
            "Недавно удалённые",
        ]
        var found: PHAssetCollection?
        all.enumerateObjects { collection, _, stop in
            if collection.assetCollectionSubtype.rawValue == 1000000201 {
                found = collection
                stop.pointee = true
                return
            }
            if let title = collection.localizedTitle, knownTitles.contains(title) {
                found = collection
                stop.pointee = true
            }
        }
        return found
    }

    // MARK: - Permanently Delete

    private func permanentlyDeleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let assetsToDelete = fetchAssets(matchingIds: Set(localIds))
        guard !assetsToDelete.isEmpty else { result(true); return }

        // Step 1: move to Recently Deleted (iOS system dialog #1)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
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

            // Step 2: permanently delete from Recently Deleted (iOS system dialog #2)
            guard let rdCollection = self.findRecentlyDeletedCollection() else {
                DispatchQueue.main.async { result(true) }
                return
            }

            // After step 1 the assets are no longer in the main library,
            // so we query inside the Recently Deleted collection by ID.
            let rdOptions = PHFetchOptions()
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

    // MARK: - Empty Recently Deleted

    private func emptyRecentlyDeleted(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let rdCollection = self.findRecentlyDeletedCollection() else {
                DispatchQueue.main.async { result(0) }
                return
            }
            // Do NOT use includeAllBurstAssets here — it would pull in main-library
            // burst frames and corrupt the count / unintentionally delete them.
            let rdAssets = PHAsset.fetchAssets(in: rdCollection, options: nil)
            let count = rdAssets.count
            guard count > 0 else {
                DispatchQueue.main.async { result(0) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(rdAssets)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(count)
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
    }

    // MARK: - Get Asset Data

    private func getAssetData(assetId: String, size: Int, result: @escaping FlutterResult) {
        guard let asset = fetchAssets(matchingIds: [assetId]).first else {
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
