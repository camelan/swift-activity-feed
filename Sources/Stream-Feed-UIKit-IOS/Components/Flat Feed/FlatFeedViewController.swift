//
//  FeedViewController.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 17/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import GetStream
import Reusable
import SnapKit

public enum GetStreamFeedEntryPoint {
    case timeline
    case followingFeeds
}

/// A flat feed view controller.
open class FlatFeedViewController<T: ActivityProtocol>: BaseFlatFeedViewController<T>, UITableViewDelegate
    where T.ActorType: UserProtocol & UserNameRepresentable & AvatarRepresentable,
    T.ReactionType == GetStream.Reaction<ReactionExtraData, T.ActorType> {

    /// A block type for the removing of an action.
    public typealias RemoveActivityAction = (_ activity: T) -> Void
    /// A banner view to show realtime updates. See `BannerView`.
//    public var bannerView: UIView & BannerViewProtocol = BannerView.make()
    private var subscriptionId: SubscriptionId?
    /// A flat feed presenter for the presentation logic.
    public var presenter: FlatFeedPresenter<T>?
    /// A block for the removing of an action.
    public var removeActivityAction: RemoveActivityAction?

    let currentUser = Client.feedSharedClient.currentUser as? User
    public var isCurrentUser: Bool = false
    public var autoLikeEnabled: Bool = false
    public var timelineVideoEnabled: Bool = false
    public var localizedNavigationTitle: String = ""
    public var pageSize: Int = 10
    public var reportUserAction: ((String, String) -> Void)?
    public var shareTimeLinePostAction: ((String?) -> Void)?
    public var navigateToUserProfileAction: ((String) -> Void)?
    public var navigateToPostDetails: ((String) -> Void)?
    public var logErrorAction: ((String, String) -> Void)?
    public var entryPoint: GetStreamFeedEntryPoint = .timeline

    open override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        reloadData()

//        bannerView.addTap { [weak self] in
//            $0.hide()
//            self?.reloadData()
//        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: animated)
        }
    }

    /// Returns the activity presenter by the table section.
    public func activityPresenter(in section: Int) -> ActivityPresenter<T>? {
        if let presenter = presenter, section < presenter.count {
            return presenter.items[section]
        }

        return nil
    }

    open override func reloadData() {
        let paginationLimit: Pagination = .none
        presenter?.load(paginationLimit, completion: dataLoaded)
    }

    open override func dataLoaded(_ error: Error?) {
//        bannerView.hide()
        tabBarItem.badgeValue = nil
        if let error = error {
            logErrorAction?("something went wrong when load feed data", "\(error.localizedDescription)")
        }
        super.dataLoaded(error)
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        guard let presenter = presenter else {
            return 0
        }

        return presenter.count + (presenter.hasNext ? 1 : 0)
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activityPresenter(in: section)?.cellsCount ?? 1
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let activityPresenter = activityPresenter(in: indexPath.section),
              let cell = tableView.postCell(at: indexPath, presenter: activityPresenter) else {
            if let presenter = presenter, presenter.hasNext, entryPoint == .followingFeeds {
                presenter.loadNext(completion: dataLoaded)
                return tableView.dequeueReusableCell(for: indexPath) as PaginationTableViewCell
            }

            return .unused
        }

        if let cell = cell as? PostAttachmentImagesTableViewCell {
            cell.collectionView.isUserInteractionEnabled = false
        }

        if let cell = cell as? PostHeaderTableViewCell {
            cell.ImagePostButton.isUserInteractionEnabled = false
            if let profilePictureURL = activityPresenter.originalActivity.actor.avatarURL?.absoluteString {
                cell.updateAvatar(with: profilePictureURL)
            }
            cell.setActivity(with: activityPresenter.originalActivity as! Activity, timelineVideoEnabled: timelineVideoEnabled)
            cell.userProfileButton.isUserInteractionEnabled = (entryPoint != .timeline)
            cell.userProfileButton.isHidden = (entryPoint == .timeline)
            cell.postSettingsTapped = { [weak self] activity in
                self?.postSettingsAction(activity: activity)
            }

            cell.profileImageTapped = { [weak self] actorId in
                self?.navigateToUserProfileAction?(actorId)
            }

        } else if let cell = cell as? PostActionsTableViewCell {
            cell.setActivity(with: activityPresenter.originalActivity as! Activity)
            sharePostAction(cell)
            updateActions(in: cell, activityPresenter: activityPresenter)
        }
        return cell
    }

    public func loadNext() {
        if let presenter = presenter, presenter.hasNext, !presenter.isPrefetching {
              presenter.loadNext(completion: dataLoaded)
          }
    }

    private func sharePostAction(_ cell: PostActionsTableViewCell) {
        cell.sharePostAction = { [weak self] activity in
            guard let self else { return }
            guard let activityId = activity?.id else {
                self.shareTimeLinePostAction?(nil)
                return
            }
            self.shareTimeLinePostAction?(activityId)
        }
    }

    private func postSettingsAction(activity: Activity) {
        let activityID = activity.id
        if isCurrentUser {
            openPostSettingOptions(activityId: activityID)
        } else {
            reportUserConfirmation(activityId: activityID)
        }
    }

    private func openPostSettingOptions(activityId: String) {
//        let editPostAction: AlertAction = ("Edit post", .destructive, { [weak self] in
//            guard let self = self else { return }
//            guard let activity = self.presenter?.items.filter({ $0.originalActivity.id == activityId }).first as? Activity else { return }
//            self.editPostAction(activity: activity)
//        }, true)

        let removePostAction: AlertAction = ("Delete post", .destructive, { [weak self] in
            guard let self = self else { return }
            guard let activity = self.presenter?.items.filter({ $0.originalActivity.id == activityId }).first else { return }
            self.presenter?.remove(activity: activity.activity as! Activity, { [weak self] error in
                if let error = error {
                    self?.logErrorAction?("Something went wrong when remove an activity", "\(error.localizedDescription)")
                }
                self?.onPostUpdate?()
            })
        }, true)

        let cancelAction: AlertAction = ("Cancel", .cancel, {}, true)

        //"Timeline Post Settings"
        //editPostAction
        self.alertWithAction(title: "Are you sure you want to delete this post?", message: nil, alertStyle: .actionSheet, tintColor: nil, actions: [removePostAction, cancelAction])
    }

    private func reportUserConfirmation(activityId: String) {
        let reportUsertAction: AlertAction = ("Report", .destructive, { [weak self] in
            guard let self = self else { return }
            guard let userId = currentUser?.id else { return }
            self.reportUserAction?(userId, activityId)
        }, true)

        let cancelAction: AlertAction = ("Cancel", .cancel, {}, true)

        self.alertWithAction(title: "Are you sure you want to report this post?", message: nil, alertStyle: .actionSheet, tintColor: nil, actions: [reportUsertAction, cancelAction])
    }

    func editPostAction(activity: Activity) {
       performSegue(show: EditPostViewController.self, sender: activity)
    }

    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return removeActivityAction != nil && indexPath.row == 0
    }

    open override func tableView(_ tableView: UITableView,
                                 commit editingStyle: UITableViewCell.EditingStyle,
                                 forRowAt indexPath: IndexPath) {
        if editingStyle == .delete,
            let removeActivityAction = removeActivityAction,
            let activityPresenter = activityPresenter(in: indexPath.section) {
            removeActivityAction(activityPresenter.activity)
        }
    }

    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellType = activityPresenter(in: indexPath.section)?.cellType(at: indexPath.row) else {
            return
        }

        if case .attachmentOpenGraphData(let ogData) = cellType {
            showOpenGraphData(with: ogData)
        }
    }
}

// MARK: - Subscription for Updates

extension FlatFeedViewController {

    /// Subscribes for the realtime updates.
    open func subscribeForUpdates() {
        subscriptionId = presenter?.subscriptionPresenter.subscribe(clientType: Client.feedSharedClient, { [weak self] in
            if let self = self, let response = try? $0.get() {
                let newCount = response.newActivities.count
                let deletedCount = response.deletedActivitiesIds.count
                let text: String

                if newCount > 0 {
                    text = self.subscriptionNewItemsTitle(with: newCount)
                    self.tabBarItem.badgeValue = String(newCount)
                } else if deletedCount > 0 {
                    text = self.subscriptionDeletedItemsTitle(with: deletedCount)
                    self.tabBarItem.badgeValue = String(deletedCount)
                } else {
                    return
                }
                self.onPostUpdate?()
//                self.bannerView.show(text, in: self)
            }
        })
    }

    /// Unsubscribes from the realtime updates.
    public func unsubscribeFromUpdates() {
        subscriptionId = nil
    }

    /// Return a title of new activies for the banner view on updates.
    open func subscriptionNewItemsTitle(with count: Int) -> String {
        return "You have \(count) new activit\(count == 1 ? "y" : "ies")"
    }

    /// Return a title of removed activities for the banner view on updates.
    open func subscriptionDeletedItemsTitle(with count: Int) -> String {
        return "You have \(count) deleted activit\(count == 1 ? "y" : "ies")"
    }
}
