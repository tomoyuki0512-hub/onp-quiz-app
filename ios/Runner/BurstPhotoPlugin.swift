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
            let args = call.arguments as? [String: Any]
            let includeRecentlyDeleted = args?["includeRecentlyDeleted"] as? Bool ?? false
            getBurstGroups(includeRecentlyDeleted: includeRecentlyDeleted, result: result)
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

    private func getBurstGroups(includeRecentlyDeleted: Bool, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allGroups: [String: (assets: [PHAsset], isRecentlyDeleted: Bool)] = [:]

            // 通常ライブラリのバースト写真を取得 (burstIdentifier が nil でないものがバースト写真)
            let options = PHFetchOptions()
            options.includeAllBurstAssets = true
            let fetchResult = PHAsset.fetchAssets(with: options)

            fetchResult.enumerateObjects { asset, _, _ in
                guard let burstId = asset.burstIdentifier else { return }
                if allGroups[burstId] == nil {
                    allGroups[burstId] = (assets: [], isRecentlyDeleted: false)
                }
                allGroups[burstId]!.assets.append(asset)
            }

            // 最近削除した項目のバースト写真を取得 (iOS 16+)
            if includeRecentlyDeleted {
                if #available(iOS 16, *) {
                    let recentlyDeletedCollections = PHAssetCollection.fetchAssetCollections(
                        with: .smartAlbum,
                        subtype: .smartAlbumRecentlyDeleted,
                        options: nil
                    )
                    if let recentlyDeletedAlbum = recentlyDeletedCollections.firstObject {
                        let rdOptions = PHFetchOptions()
                        rdOptions.includeAllBurstAssets = true
                        let rdFetch = PHAsset.fetchAssets(in: recentlyDeletedAlbum, options: rdOptions)
                        rdFetch.enumerateObjects { asset, _, _ in
                            guard let burstId = asset.burstIdentifier else { return }
                            let rdBurstId = "recently_deleted_\(burstId)"
                            if allGroups[rdBurstId] == nil {
                                allGroups[rdBurstId] = (assets: [], isRecentlyDeleted: true)
                            }
                            allGroups[rdBurstId]!.assets.append(asset)
                        }
                    }
                }
            }

            let payload: [[String: Any]] = allGroups.compactMap { (burstId, info) in
                guard info.assets.count >= 2 else { return nil }
                let assetIds = info.assets.map { $0.localIdentifier }
                let bestPickId = info.assets.first(where: { $0.representsBurst })?.localIdentifier
                return [
                    "burstId": burstId,
                    "assetIds": assetIds,
                    "bestPickId": bestPickId as Any,
                    "count": info.assets.count,
                    "isRecentlyDeleted": info.isRecentlyDeleted
                ]
            }.sorted {
                ($0["count"] as! Int) > ($1["count"] as! Int)
            }

            DispatchQueue.main.async {
                result(payload)
            }
        }
    }

    // MARK: - Delete (→ 最近削除した項目へ移動)

    private func deleteAssets(localIds: [String], result: @escaping FlutterResult) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: nil)
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

    // MARK: - Permanently Delete (最近削除した項目から完全削除, iOS 16+)

    private func permanentlyDeleteAssets(localIds: [String], result: @escaping FlutterResult) {
        guard #available(iOS 16, *) else {
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "完全削除にはiOS 16以上が必要です",
                details: nil
            ))
            return
        }

        let recentlyDeletedCollections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumRecentlyDeleted,
            options: nil
        )
        guard let recentlyDeletedAlbum = recentlyDeletedCollections.firstObject else {
            result(FlutterError(
                code: "NO_ALBUM",
                message: "最近削除した項目アルバムが見つかりません",
                details: nil
            ))
            return
        }

        let fetchResult = PHAsset.fetchAssets(in: recentlyDeletedAlbum, options: nil)
        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if localIds.contains(asset.localIdentifier) {
                assetsToDelete.append(asset)
            }
        }

        guard !assetsToDelete.isEmpty else {
            result(true)
            return
        }

        let assetsArray = assetsToDelete as NSArray
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsArray)
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
}
