import Flutter
import Photos
import UIKit

public class BurstPhotoPlugin: NSObject, FlutterPlugin {

    /// localIdentifier -> PHAsset のキャッシュ。
    /// getBurstGroups で全ライブラリを 1 回だけ列挙して構築し、
    /// サムネイル取得・保存・削除はここを参照することで
    /// 都度の全件列挙（O(全写真数)）を避ける。
    private var assetCache: [String: PHAsset] = [:]

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
        case "saveAndDeleteBurst":
            guard let args = call.arguments as? [String: Any],
                  let keepIds = args["keepIds"] as? [String],
                  let burstIds = args["burstIds"] as? [String] else {
                result(FlutterError(code: "BAD_ARGS", message: "keepIds / burstIds required", details: nil))
                return
            }
            saveAndDeleteBurst(keepIds: keepIds, burstIds: burstIds, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helper

    /// キャッシュ優先でアセットを取得する。
    /// キャッシュに無い ID があれば、その分だけ全列挙でフォールバック取得する。
    /// （PHAsset.fetchAssets(withLocalIdentifiers:) は includeAllBurstAssets を
    ///  無視するため、非代表バーストフレームを取りこぼす。列挙が確実。）
    private func resolveAssets(for ids: [String]) -> [PHAsset] {
        var found: [PHAsset] = []
        var missing: Set<String> = []
        for id in ids {
            if let cached = assetCache[id] {
                found.append(cached)
            } else {
                missing.insert(id)
            }
        }
        guard !missing.isEmpty else { return found }

        let opts = PHFetchOptions()
        opts.includeAllBurstAssets = true
        PHAsset.fetchAssets(with: opts).enumerateObjects { [weak self] asset, _, stop in
            if missing.contains(asset.localIdentifier) {
                self?.assetCache[asset.localIdentifier] = asset
                found.append(asset)
                missing.remove(asset.localIdentifier)
                if missing.isEmpty { stop.pointee = true }
            }
        }
        return found
    }

    // MARK: - Permission

    private func requestPermission(result: @escaping FlutterResult) {
        let handler: (PHAuthorizationStatus) -> Void = { status in
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
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
        } else {
            PHPhotoLibrary.requestAuthorization(handler)
        }
    }

    // MARK: - Get Burst Groups

    private func getBurstGroups(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var groups: [String: [PHAsset]] = [:]
            var cache: [String: PHAsset] = [:]

            let opts = PHFetchOptions()
            opts.includeAllBurstAssets = true
            PHAsset.fetchAssets(with: opts).enumerateObjects { asset, _, _ in
                guard let burstId = asset.burstIdentifier else { return }
                groups[burstId, default: []].append(asset)
                cache[asset.localIdentifier] = asset
            }

            // キャッシュを差し替え（以降のサムネイル/保存/削除で参照される）
            self.assetCache = cache

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
                // 新しい順
                ($0["createdAt"] as? Int ?? 0) > ($1["createdAt"] as? Int ?? 0)
            }

            DispatchQueue.main.async { result(payload) }
        }
    }

    // MARK: - Get Asset Thumbnail

    private func getAssetThumbnail(assetId: String, size: Int, result: @escaping FlutterResult) {
        guard let asset = resolveAssets(for: [assetId]).first else {
            result(nil)
            return
        }

        let manager = PHImageManager.default()
        let targetSize = CGSize(width: CGFloat(size), height: CGFloat(size))
        let reqOpts = PHImageRequestOptions()
        reqOpts.deliveryMode = .highQualityFormat
        reqOpts.isNetworkAccessAllowed = true
        // 縮小サムネイルなので 1 回だけ最終画像を受け取る
        reqOpts.resizeMode = .fast

        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: reqOpts) { image, info in
            // 低解像度の途中経過は無視し、最終画像のみ返す
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
            guard let image = image, let data = image.jpegData(compressionQuality: 0.85) else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: data))
            }
        }
    }

    // MARK: - Save Selected & Delete Burst (atomic)

    /// 選択フレーム（keepIds）をオリジナル品質の独立した写真として保存し、
    /// 同時にバースト全体（burstIds）を削除する。
    ///
    /// 保存と削除を 1 つの performChanges にまとめることで:
    ///   - iOS の削除確認ダイアログは 1 回だけ
    ///   - ユーザーがキャンセルした場合は保存もまとめてロールバック
    ///     （＝コピーだけ残って重複する問題を解消）
    private func saveAndDeleteBurst(keepIds: [String], burstIds: [String], result: @escaping FlutterResult) {
        let burstAssets = resolveAssets(for: burstIds)
        guard !burstAssets.isEmpty else {
            result(FlutterError(code: "NO_ASSETS", message: "対象のバースト写真が見つかりませんでした", details: nil))
            return
        }
        let keepAssets = resolveAssets(for: keepIds)
        guard !keepAssets.isEmpty else {
            result(FlutterError(code: "NO_SELECTION", message: "保存する写真が選択されていません", details: nil))
            return
        }

        // 1) 各選択フレームのオリジナルファイルデータを非同期取得
        let manager = PHAssetResourceManager.default()
        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var items: [(data: Data, filename: String, creationDate: Date?, location: CLLocation?)] = []
        var fetchFailed = false

        for asset in keepAssets {
            let resources = PHAssetResource.assetResources(for: asset)
            guard let resource = resources.first(where: { $0.type == .photo })
                    ?? resources.first(where: { $0.type == .fullSizePhoto })
                    ?? resources.first else {
                fetchFailed = true
                continue
            }

            dispatchGroup.enter()
            var buffer = Data()
            let reqOpts = PHAssetResourceRequestOptions()
            reqOpts.isNetworkAccessAllowed = true

            manager.requestData(
                for: resource,
                options: reqOpts,
                dataReceivedHandler: { chunk in buffer.append(chunk) },
                completionHandler: { error in
                    lock.lock()
                    if error != nil {
                        fetchFailed = true
                    } else {
                        items.append((
                            data: buffer,
                            filename: resource.originalFilename,
                            creationDate: asset.creationDate,
                            location: asset.location
                        ))
                    }
                    lock.unlock()
                    dispatchGroup.leave()
                }
            )
        }

        // 2) 取得完了後、保存＋削除をアトミックに実行
        dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
            if fetchFailed || items.isEmpty {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FETCH_FAILED",
                                        message: "元の写真データの取得に失敗しました。削除は行っていません。",
                                        details: nil))
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                for item in items {
                    let creation = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = item.filename
                    creation.addResource(with: .photo, data: item.data, options: options)
                    // メタデータ（撮影日時・位置情報）を明示的に引き継ぐ
                    creation.creationDate = item.creationDate
                    creation.location = item.location
                }
                PHAssetChangeRequest.deleteAssets(burstAssets as NSArray)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        // 削除されたアセットをキャッシュから除去
                        for id in burstIds { self.assetCache.removeValue(forKey: id) }
                        result(true)
                        return
                    }
                    let nsError = error as NSError?
                    // ユーザーが iOS の削除確認をキャンセルした場合
                    if let nsError = nsError,
                       nsError.domain == PHPhotosErrorDomain,
                       nsError.code == 3072 /* PHPhotosError.userCancelled */ {
                        result(FlutterError(code: "CANCELLED", message: "キャンセルされました", details: nil))
                    } else {
                        result(FlutterError(code: "OP_FAILED",
                                            message: nsError?.localizedDescription ?? "保存と削除に失敗しました",
                                            details: nil))
                    }
                }
            })
        }
    }
}
