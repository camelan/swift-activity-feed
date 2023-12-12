//
//  CustomActivity.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 17/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation
import GetStream

/// A reaction with `ReactionExtraData` and `User`. See `ReactionExtraData`, `User`.
public typealias Reaction = GetStream.Reaction<ReactionExtraData, User>

/// An enriched activity with `User` type, `ActivityObject` as object type and `Reaction` as reation type.
/// It has additional properties: text and attachment. See `AttachmentRepresentable`.
public final class Activity: EnrichedActivity<User, ActivityObject, Reaction>, TextRepresentable, AttachmentRepresentable {

    private enum CodingKeys: String, CodingKey {
        case text
        case attachments
        case petId
        case media
    }

    public var text: String?
    public var attachment: ActivityAttachment?
    public var petId: String?
    public var media: [UploadedMediaItem]?

    public var original: Activity {
        switch object {
        case .repost(let activity):
            return activity
        default:
            return self
        }
    }

    public init(actor: User, verb: Verb, object: ActivityObject, feedIds: FeedIds? = nil) {
        super.init(actor: actor, verb: verb, object: object, feedIds: feedIds)
    }

    required public init(actor: User,
                         verb: Verb,
                         object: ActivityObject,
                         foreignId: String? = nil,
                         time: Date? = nil,
                         feedIds: FeedIds? = nil,
                         originFeedId: FeedId? = nil) {
        super.init(actor: actor, verb: verb, object: object, feedIds: feedIds)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        attachment = try container.decodeIfPresent(ActivityAttachment.self, forKey: .attachments)
        petId = try container.decodeIfPresent(String.self, forKey: .petId)
        media = try container.decodeIfPresent([UploadedMediaItem].self , forKey: .media)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(attachment, forKey: .attachments)
        try container.encodeIfPresent(petId, forKey: .petId)
        try container.encodeIfPresent(media, forKey: .media)
        try super.encode(to: encoder)
    }
}
extension Activity {
    public func mappedMediaItems(timelineVideoEnabled: Bool) -> [UploadedMediaItem]? {
        if let mediaItems = validMediaItems(), timelineVideoEnabled {
            return mediaItems
        }
        if let objectMediaItem = createObjectMediaItem() {
            return appendAttachedMediaItems(to: objectMediaItem)
        }
        return nil
    }

    private func validMediaItems() -> [UploadedMediaItem]? {
        if let mediaItems = media, !mediaItems.isEmpty {
            return mediaItems
        }
        return nil
    }

    private func createObjectMediaItem() -> UploadedMediaItem? {
        if let objectImageURL = object.imageURL {
            return UploadedMediaItem(mediaType: "image", imageURL: objectImageURL, videoURL: nil, thumbnailURL: nil)
        }
        return nil
    }

    private func appendAttachedMediaItems(to objectMediaItem: UploadedMediaItem) -> [UploadedMediaItem] {
        if let attachmentImages = attachment?.imageURLs, !attachmentImages.isEmpty {
            var mappedMediaItems = attachmentImages.map { UploadedMediaItem(mediaType: "image", imageURL: $0, videoURL: nil, thumbnailURL: nil) }
            mappedMediaItems.insert(objectMediaItem, at: 0)
            return mappedMediaItems
        } else {
            return [objectMediaItem]
        }
    }
}
