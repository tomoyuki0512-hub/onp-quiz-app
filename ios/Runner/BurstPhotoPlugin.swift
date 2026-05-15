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
        let localIdSet = Set(localIds)
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: options)
        guard fetchResult.count > 0 else {
            result(true)
            return
        }

        // includeAllBurstAssets=true により要求していない代表写真が混入する場合があるため
        // 明示的に要求した ID のみに絞り込む（残す1枚を誤って削除しないよう保護）
        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if localIdSet.contains(asset.localIdentifier) {
                assetsToDelete.append(asset)
            }
        }
        guard !assetsToDelete.isEmpty else {
            result(true)
            return
        }

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

    /// 「最近削除した項目」スマートアルバムを検索する。
    /// PHAssetCollectionSubtype.smartAlbumRecentlyDeleted は公開SDKに存在しないため、
    /// 全スマートアルバムを列挙し、プライベート定数の rawValue (=1000000201) または
    /// ローカライズされたタイトルで判定する。
    /// （rawValue 206 は smartAlbumRecentlyAdded であって RecentlyDeleted ではない点に注意）
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

    // MARK: - Permanently Delete (最近削除した項目を経由して完全削除)

    private func permanentlyDeleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let localIdSet = Set(localIds)
        let options = PHFetchOptions()
        options.includeAllBurstAssets = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: options)
        guard fetchResult.count > 0 else {
            result(true)
            return
        }

        // 要求した ID のみに絞り込む
        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if localIdSet.contains(asset.localIdentifier) {
                assetsToDelete.append(asset)
            }
        }
        guard !assetsToDelete.isEmpty else {
            result(true)
            return
        }

        // Step 1: 通常削除 → 最近削除した項目へ移動
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

            // Step 2: 最近削除した項目から完全削除
            guard let rdCollection = self.findRecentlyDeletedCollection() else {
                // 最近削除した項目にアクセス不可 → 通常削除のみで完了
                DispatchQueue.main.async { result(true) }
                return
            }

            // step 1 後は localIdentifier でメインライブラリから検索しても 0 件になるため
            // 最近削除したアルバム内を predicate でフィルタして取得する。
            // includeAllBurstAssets はメインライブラリのバースト写真を混入させるため使わない。
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
            // includeAllBurstAssets を使うとメインライブラリのバースト写真まで
            // 混入するため、コレクション内のみを対象にするオプションなしで取得する
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
