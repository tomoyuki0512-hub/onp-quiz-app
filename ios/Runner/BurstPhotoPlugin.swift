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
                let bestPickId = assets.first(where: { $0.representsBurst })?.localIdentifier
                return [
                    "burstId": burstId,
                    "assetIds": assetIds,
                    "bestPickId": bestPickId as Any,
                    "count": assets.count,
                    "isRecentlyDeleted": false
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

            let rdOptions = PHFetchOptions()
            rdOptions.includeAllBurstAssets = true
            let rdAssets = PHAsset.fetchAssets(withLocalIdentifiers: localIds, options: rdOptions)
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
}
