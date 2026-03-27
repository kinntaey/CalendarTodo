import Foundation
import Supabase

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class AvatarService {
    public static let shared = AvatarService()
    private let supabase = SupabaseService.shared.client
    private let bucketName = "avatars"

    private init() {}

    // MARK: - Upload Avatar

    /// Uploads avatar image data, returns the public URL with cache-busting timestamp
    public func uploadAvatar(imageData: Data) async throws -> String {
        let userID = try await supabase.auth.session.user.id
        let fileName = "\(userID.uuidString.lowercased()).jpg"

        // Resize and compress
        let compressed = compressImage(imageData, maxSize: 300, quality: 0.8)

        // Upload to Supabase Storage (upsert to overwrite)
        try await supabase.storage
            .from(bucketName)
            .upload(
                path: fileName,
                file: compressed,
                options: .init(contentType: "image/jpeg", upsert: true)
            )

        // Get public URL with cache-busting
        let baseURL = try supabase.storage
            .from(bucketName)
            .getPublicURL(path: fileName)

        let avatarURL = "\(baseURL.absoluteString)?v=\(Int(Date.now.timeIntervalSince1970))"

        // Update profile
        try await updateProfileAvatarURL(avatarURL)

        return avatarURL
    }

    // MARK: - Delete Avatar

    public func deleteAvatar() async throws {
        let userID = try await supabase.auth.session.user.id
        let fileName = "\(userID.uuidString.lowercased()).jpg"

        try await supabase.storage
            .from(bucketName)
            .remove(paths: [fileName])

        // Clear avatar_url in profile
        struct AvatarUpdate: Encodable {
            let avatar_url: String?
        }

        try await supabase
            .from("profiles")
            .update(AvatarUpdate(avatar_url: nil))
            .eq("id", value: userID)
            .execute()
    }

    // MARK: - Update Profile URL

    private func updateProfileAvatarURL(_ url: String) async throws {
        let userID = try await supabase.auth.session.user.id

        struct AvatarUpdate: Encodable {
            let avatar_url: String
        }

        try await supabase
            .from("profiles")
            .update(AvatarUpdate(avatar_url: url))
            .eq("id", value: userID)
            .execute()
    }

    // MARK: - Image Compression

    private func compressImage(_ data: Data, maxSize: CGFloat, quality: CGFloat) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }

        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: quality) ?? data
        #else
        return data
        #endif
    }
}
