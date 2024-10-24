//
//  DetailViewController.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 01/02/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import SnapKit
import GetStream
import IQKeyboardManagerSwift

/// Detail View Controller section types.
public struct DetailViewControllerSectionTypes: OptionSet, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// An activity section.
    public static let activity = DetailViewControllerSectionTypes(rawValue: 1 << 0)
    /// A likes section.
    public static let likes = DetailViewControllerSectionTypes(rawValue: 1 << 1)
    /// A reposts section.
    public static let reposts = DetailViewControllerSectionTypes(rawValue: 1 << 2)
    /// A comments section.
    public static let comments = DetailViewControllerSectionTypes(rawValue: 1 << 3)
}

/// Detail View Controller section data
public struct DetailViewControllerSection {
    /// A section type.
    public let section: DetailViewControllerSectionTypes
    /// A title of the section.
    public let title: String?
    /// A number of items in section.
    public let count: Int
}

/// Detail View Controller for an activity from `ActivityPresenter`.
///
/// It shows configurable sections of the activity details:
/// - activity content
/// - likes
/// - reposts
/// - comments
///
/// Contains `TextToolBar` for the adding of new comments.
open class DetailViewController<T: ActivityProtocol>: BaseFlatFeedViewController<T>, UITableViewDelegate, UITextViewDelegate
    where T.ActorType: UserProtocol & UserNameRepresentable & AvatarRepresentable,
          T.ReactionType == GetStream.Reaction<ReactionExtraData, T.ActorType> {

    /// An text view for new comments. See `TextToolBar`.
    public let textToolBar = TextToolBar.make()
    /// A comments paginator. See `ReactionPaginator`.
    public var reactionPaginator: ReactionPaginator<ReactionExtraData, T.ActorType>?
    private var replyToComment: T.ReactionType?
    /// Section types in the table view.
    public var sections: DetailViewControllerSectionTypes = .activity
    /// A list of section data for the table view.
    public private(set) var sectionsData: [DetailViewControllerSection] = []
    /// A number of reply comments for the top level comments.
    public var childCommentsCount = 0
    /// Show the text view for the adding new comments.
    public var canAddComment = true
    /// Show the section title even if it's empty.
    public var showZeroSectionTitle = true

    let currentUser = Client.feedSharedClient.currentUser as? User
    public var reportUserAction: ((String, String) -> Void)?
    public var navigateToUserProfileAction: ((String) -> Void)?
    public var shareTimeLinePostAction: ((String?) -> Void)?
    public var logErrorAction: ((String, String) -> Void)?
    public var feedLoadingCompletion: ((Error?) -> Void)?

    public var isCurrentUser: Bool = false
    public var autoLikeEnabled: Bool = false
    public var timelineVideoEnabled = false
    public var presenter: FlatFeedPresenter<T>?
    public var activityId: String?
    public var currentUserId: String?


    /// An activity presenter. See `ActivityPresenter`.
    public var activityPresenter: ActivityPresenter<T>? {
        didSet {
            if let activityPresenter = activityPresenter {
                reactionPaginator = activityPresenter.reactionPaginator(activityId: activityPresenter.originalActivity.id,
                                                                        reactionKind: .comment)
            }
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        loadActivityByID()
        updateSectionsIndex()

        if sections.contains(.comments) {
            reloadComments()

            if canAddComment {
                if let user = User.current {
                    self.setupCommentTextField(avatarURL: user.avatarURL)
                } else {
                    if Client.feedSharedClient.currentUser != nil {
                        print("❌ The current user was not setupped with correct type. " +
                            "Did you setup `GetStream.User` and not `GetStreamActivityFeed.User`?")
                    } else {
                        print("❌ The current user not found. Did you setup the user with `setupUser`?")
                    }
                    setupCommentTextField(avatarURL: nil)
                }
            }
        }

        reloadData()

        if isModal {
            setupNavigationBarForModallyPresented()
        }

        keyboardBinding()
    }

    private func keyboardBinding() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardSize.height
            // Update your textToolBar bottom constraint constant here based on the keyboardHeight
            // For example, if you have a constraint called textToolBarBottomConstraint:
            textToolBar.bottomConstraint?.update(offset: -keyboardHeight)
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        // Reset your textToolBar bottom constraint constant to its original value (e.g., 0)
        textToolBar.bottomConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }


    @objc func willResignActive() {
        view.endEditing(true)
    }

    open override func viewWillAppear(_ animated: Bool) {
        Task(priority: .userInitiated) { @MainActor in
            IQKeyboardManager.shared.enable = false
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        Task(priority: .userInitiated) { @MainActor in
            IQKeyboardManager.shared.enable = true
        }
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }


    private func updateSectionsIndex() {
        guard let activityPresenter = activityPresenter else {
            self.sectionsData = []
            return
        }

        let originalActivity = activityPresenter.originalActivity
        var sectionsData: [DetailViewControllerSection] = []

        if sections.contains(.activity) {
            sectionsData.append(DetailViewControllerSection(section: .activity,
                                                            title: nil,
                                                            count: activityPresenter.cellsCount - 1))
        }

        if sections.contains(.likes), (originalActivity.likesCount > 0 || showZeroSectionTitle) {
            let title = sectionTitle(for: .likes)
            let count = originalActivity.likesCount > 0 ? 1 : 0
            sectionsData.append(DetailViewControllerSection(section: .likes, title: title, count: count))
        }

        if sections.contains(.reposts), (originalActivity.repostsCount > 0 || showZeroSectionTitle) {
            let title = sectionTitle(for: .reposts)
            sectionsData.append(DetailViewControllerSection(section: .reposts, title: title, count: originalActivity.repostsCount))
        }

        if sections.contains(.comments), let reactionPaginator = reactionPaginator {
            let title = sectionTitle(for: .comments)
            sectionsData.append(DetailViewControllerSection(section: .comments, title: title, count: reactionPaginator.count))
        }

        self.sectionsData = sectionsData
    }

    private func postSettingsAction(activity: Activity) {
        if isCurrentUser {
            openPostSettingOptions(activity: activity)
        } else {
            reportUserConfirmation(activity: activity)
        }
    }

    private func openPostSettingOptions(activity: Activity) {
//        let editPostAction: AlertAction = ("Edit post", .destructive, { [weak self] in
//            guard let self = self else { return }
//            self.navigateToPostDetails(with: activity)
//        }, true)

        let removePostAction: AlertAction = ("Delete post", .destructive, { [weak self] in
            guard let self = self else { return }
            self.presenter?.remove(activity: activity, { error in
                if let error = error {
                    self.logErrorAction?("[Post details] something went wrong when delete post", "\(error.localizedDescription)")
                }
                DispatchQueue.main.async { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            })
        }, true)

        let cancelAction: AlertAction = ("Cancel", .cancel, {}, true)

        //"Timeline Post Settings"
        //editPostAction,
        self.alertWithAction(title: "Are you sure you want to delete this post?", message: nil, alertStyle: .actionSheet, tintColor: nil, actions: [removePostAction, cancelAction])

    }

    private func reportUserConfirmation(activity: Activity) {
        let reportUsertAction: AlertAction = ("Report", .destructive, { [weak self] in
            guard let self = self else { return }
            guard let userId = currentUser?.id else { return }
            self.reportUserAction?(userId, activity.id)
        }, true)

        let cancelAction: AlertAction = ("Cancel", .cancel, {}, true)

        self.alertWithAction(title: "Are you sure you want to report this post?", message: nil, alertStyle: .actionSheet, tintColor: nil, actions: [reportUsertAction, cancelAction])
    }

    private func navigateToPostDetails(with activity: Activity) {
        guard let userFeedId: FeedId = FeedId(feedSlug: "user",
                                              client: Client.feedSharedClient) else { return }
        let imageCompression: Double = 0.5
        let videoMaximumDurationInMinutes: Double = 2.0
        let videoCompression: Int = 100
        let timeLineVideoEnabled: Bool = false
        let editPostViewController = EditPostViewController.fromBundledStoryboard()
        editPostViewController.presenter = EditPostPresenter(flatFeed: Client.feedSharedClient.flatFeed(userFeedId),
                                                             view: editPostViewController,
                                                             activity: activity,
                                                             petId: nil,
                                                             imageCompression: imageCompression,
                                                             videoMaximumDurationInMinutes: videoMaximumDurationInMinutes,
                                                             videoCompression: videoCompression,
                                                             timeLineVideoEnabled: timeLineVideoEnabled,
                                                             logErrorAction: { _, _ in })
        editPostViewController.entryPoint = .editPost
        editPostViewController.modalPresentationStyle = .fullScreen

        self.navigationController?.pushViewController(editPostViewController, animated: true)
    }

    private func reloadComments(isNewCommentSent: Bool = false) {
        reactionPaginator?.reset()
        reactionPaginator?.load(.limit(100), completion: { [weak self] error in
            self?.commentsLoaded(isNewCommentSent: isNewCommentSent, error)
        })
    }

    /// Return a title of the section by the section type.
    open func sectionTitle(for type: DetailViewControllerSectionTypes) -> String? {
        if type == .likes {
            return "Liked"
        }

        if type == .reposts {
            return "Reposts"
        }

        if type == .comments {
            return "Comments"
        }

        return nil
    }

    /// Return a title of in the section by the section index.
    public func sectionTitle(in section: Int) -> String? {
        return section < sectionsData.count ? sectionsData[section].title : nil
    }

    // MARK: - Table View Data Source

    open override func setupTableView() {
        tableView.delegate = self

        if canAddComment, sections.contains(.comments) {
            tableView.snp.makeConstraints { $0.left.top.right.equalToSuperview() }
        } else {
            tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        }
    }

    open override func setupRefreshControl() {
        if sections.contains(.comments) {
            tableView.refreshControl = refreshControl

            refreshControl.addValueChangedAction { [weak self] _ in
                self?.reloadComments()
            }
        }
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        guard sectionsData.count > 0 else {
            return 0
        }

        var count = sectionsData.count

        if sections.contains(.comments), let reactionPaginator = reactionPaginator {
            count -= 1 // remove the comments section from sectionsData, the rest of the sections are comments.
            let commentsCount = reactionPaginator.count + (reactionPaginator.hasNext ? 1 : 0)
            count += commentsCount

            if showZeroSectionTitle, commentsCount == 0 {
                count += 1
            }
        }

        return count
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < sectionsData.count, sectionsData[section].section != .comments {
            return max(sectionsData[section].count, showZeroSectionTitle ? 1 : 0)
        }

        guard sections.contains(.comments), let reactionPaginator = reactionPaginator else {
            return 0
        }

        guard childCommentsCount > 0 else {
            return 1
        }

        let commentIndex = self.commentIndex(in: section)

        if commentIndex < reactionPaginator.items.count {
            let comment = reactionPaginator.items[commentIndex]
            let childCommentsCount = comment.childrenCounts[.comment] ?? 0

            return min(childCommentsCount, self.childCommentsCount) + 1
        }

        return 1
    }

    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section < sectionsData.count && sectionsData.count != 1 ? sectionsData[section].title : nil
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let activityPresenter = activityPresenter, let reactionPaginator = reactionPaginator else {
            return .unused
        }
        if indexPath.section < sectionsData.count {
            let section = sectionsData[indexPath.section]

            if section.section == .activity, let cell = tableView.postCell(at: indexPath, presenter: activityPresenter, imagesTappedAction: { [weak self] mediaItems, selectedMediaItem in
                self?.showImageGallery(with: mediaItems, selectedMediaItem: selectedMediaItem, logErrorAction: self?.logErrorAction)
            }) {
                if let cell = cell as? PostHeaderTableViewCell {
                    if let profilePictureURL = activityPresenter.originalActivity.actor.avatarURL?.absoluteString {
                        cell.updateAvatar(with: profilePictureURL)
                    }
                    let activity = activityPresenter.originalActivity as! Activity
                    cell.setActivity(with: activity, timelineVideoEnabled: timelineVideoEnabled)
                    cell.postSettingsTapped = { [weak self] activity in
                        self?.postSettingsAction(activity: activity)
                    }
                    cell.photoImageTapped = { [weak self] mediaItems, selectedMediaItem in
                        self?.showImageGallery(with: mediaItems, selectedMediaItem: selectedMediaItem, logErrorAction: self?.logErrorAction)
                    }

                    cell.profileImageTapped = { [weak self] actorID in
                        self?.navigateToUserProfileAction?(actorID)
                    }
                }

                if let cell = cell as? PostActionsTableViewCell {
                    cell.setActivity(with: activityPresenter.originalActivity as! Activity)
                    sharePostAction(cell)
                    cell.isCurrentUser = isCurrentUser
                    cell.autoLikeEnabled = autoLikeEnabled
                    cell.isFromPostDetails = true
                    updateActions(in: cell, activityPresenter: activityPresenter)
                }

                return cell
            }

            if section.section == .likes, section.count > 0 {
                let cell = tableView.dequeueReusableCell(for: indexPath) as ActionUsersTableViewCell
                cell.titleLabel.text = activityPresenter.reactionTitle(for: activityPresenter.originalActivity,
                                                                       kindOf: .like,
                                                                       suffix: "liked the post")

                cell.avatarsStackView.loadImages(with:
                    activityPresenter.reactionUserAvatarURLs(for: activityPresenter.originalActivity, kindOf: .like))

                return cell
            }

            if section.section == .reposts, section.count > 0 {
                let cell = tableView.dequeueReusableCell(for: indexPath) as ActionUsersTableViewCell

                cell.titleLabel.text = activityPresenter.reactionTitle(for: activityPresenter.originalActivity,
                                                                       kindOf: .repost,
                                                                       suffix: "reposted the post")

                cell.avatarsStackView.loadImages(with:
                    activityPresenter.reactionUserAvatarURLs(for: activityPresenter.originalActivity, kindOf: .repost))

                return cell
            }

            if section.section != .comments {
                return .unused
            }
        }

        guard let comment = comment(at: indexPath) else {
            if reactionPaginator.hasNext {
                reactionPaginator.loadNext { [weak self] error in
                    self?.commentsLoaded(isNewCommentSent: false, error)
                }
                return tableView.dequeueReusableCell(for: indexPath) as PaginationTableViewCell
            }

            return .unused
        }

        let cell = tableView.dequeueReusableCell(for: indexPath) as CommentTableViewCell
        update(cell: cell, with: comment)

        if indexPath.row > 0 {
            cell.withIndent = true

            if let parentComment = self.comment(at: IndexPath(row: 0, section: indexPath.section)),
                let count = parentComment.childrenCounts[.comment],
                count > childCommentsCount,
                indexPath.row == childCommentsCount {
                cell.moreReplies = moreCommentsTitle(with: count - childCommentsCount)
            }
        } else if childCommentsCount == 0, let childCount = comment.childrenCounts[.comment], childCount > 0 {
            cell.moreReplies = moreCommentsTitle(with: childCount)
        }

        return cell
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

    /// A title for bottom comment note, that it has replies.
    open func moreCommentsTitle(with count: Int) -> String {
        return "\(count) more replies"
    }
    // MARK: - Table View - Select Cell

    open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard let activityPresenter = activityPresenter,
            indexPath.section < sectionsData.count,
            sectionsData[indexPath.section].section == .activity,
            let cellType = activityPresenter.cellType(at: indexPath.row) else {
                return false
        }

        if case .attachmentImages = cellType {
            return true
        } else if case .attachmentOpenGraphData = cellType {
            return true
        }

        return false
    }

    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let activityPresenter = activityPresenter,
            let cellType = activityPresenter.cellType(at: indexPath.row) else {
                return
        }

        if case .attachmentOpenGraphData(let ogData) = cellType {
            showOpenGraphData(with: ogData)
        }
    }

    // MARK: - Table View - Comments

    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard sections.contains(.comments), let currentUser = User.current, let comment = comment(at: indexPath) else {
            return false
        }

        return comment.user.id == currentUser.id
    }

    open override func tableView(_ tableView: UITableView,
                                 commit editingStyle: UITableViewCell.EditingStyle,
                                 forRowAt indexPath: IndexPath) {
        if editingStyle == .delete,
            let activityPresenter = activityPresenter,
            let comment = comment(at: indexPath),
            let parentComment = self.comment(at: IndexPath(row: 0, section: indexPath.section)) {
            if comment == parentComment {
                activityPresenter.reactionPresenter.remove(reaction: comment, activity: activityPresenter.activity) { [weak self] in
                    if let error = $0.error {
                        self?.logErrorAction?("[post details] something went wrong with feed reaction", "\(error.localizedDescription)")
                    } else if let self = self {
                        self.reloadComments()
                    }
                }
            } else {
                activityPresenter.reactionPresenter.remove(reaction: comment, parentReaction: parentComment) { [weak self] in
                    if let error = $0.error {
                        self?.logErrorAction?("[post details] something went wrong with parent feed reaction", "\(error.localizedDescription)")
                    } else {
                        self?.tableView.reloadData()
                    }
                }
            }
        }
    }

    private func commentIndex(in section: Int) -> Int {
        if section < sectionsData.count, sectionsData[section].section != .comments {
            return -1
        }

        return section - (sectionsData.count > 0 ? (sectionsData.count - 1) : 0)
    }

    private func comment(at indexPath: IndexPath) -> GetStream.Reaction<ReactionExtraData, T.ActorType>? {
        let commentIndex = self.commentIndex(in: indexPath.section)

        guard commentIndex >= 0, let reactionPaginator = reactionPaginator, commentIndex < reactionPaginator.count else {
            return nil
        }

        let comment = reactionPaginator.items[commentIndex]
        let childCommentIndex = indexPath.row - 1

        if childCommentIndex >= 0, let childComments = comment.latestChildren[.comment], childCommentIndex < childComments.count {
            return childComments[childCommentIndex]
        }

        return comment
    }

    private func update(cell: CommentTableViewCell, with comment: GetStream.Reaction<ReactionExtraData, T.ActorType>) {
        guard case .comment(let text) = comment.data else {
            return
        }

        cell.updateComment(name: comment.user.name, comment: text, date: comment.created)

        cell.avatarImageView.loadImage(from: comment.user.avatarURL?.absoluteString)
        // Reply button.
        cell.replyButton.addTap { [weak self] _ in
            if let self = self, case .comment(let text) = comment.data {
                self.replyToComment = comment
                self.textToolBar.replyText = "Reply to \(comment.user.name): \(text)"
                self.textToolBar.textView.becomeFirstResponder()
            }
        }
        cell.avatarUserTapped = { [weak self] in
            guard let self = self else { return }
            guard currentUserId != comment.user.id else { return }
            self.navigateToUserProfileAction?(comment.user.id)
        }
        // Like button.
        let countTitle = comment.childrenCounts[.like] ?? 0
        cell.likeButton.setTitle(countTitle == 0 ? "" : String(countTitle), for: .normal)
        cell.likeButton.isSelected = comment.hasUserOwnChildReaction(.like)

        cell.likeButton.addTap { [weak self] in
            if let activityPresenter = self?.activityPresenter, let button = $0 as? LikeButton {
                button.like(activityPresenter.originalActivity,
                            presenter: activityPresenter.reactionPresenter,
                            likedReaction: comment.userOwnChildReaction(.like),
                            parentReaction: comment,
                            userTypeOf: T.ActorType.self) { _ in }
            }
        }
    }

    private func commentsLoaded(isNewCommentSent: Bool = false, _ error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshControl.endRefreshing()
        }

        if let error = error {
            logErrorAction?("someThing went wrong when load comments",
                            "id: \(activityPresenter?.originalActivity.id ?? "") \n Error: \(error.localizedDescription)")
        } else {
            updateSectionsIndex()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.tableView.reloadData()
                if isNewCommentSent {
                    self.tableView.scrollToBottom(animated: true)
                }
            }
        }
    }

    // MARK: - Comment Text Field

    private func setupCommentTextField(avatarURL: URL?) {
        textToolBar.addToSuperview(view, placeholderText: "Leave reply")
        tableView.snp.makeConstraints { $0.bottom.equalTo(textToolBar.snp.top) }
        textToolBar.showAvatar = true
        textToolBar.avatarView.imageURL = avatarURL?.absoluteString
        textToolBar.sendButton.addTarget(self, action: #selector(send(_:)), for: .touchUpOutside)
    }


    @objc func send(_ button: UIButton) {
        let parentReaction = textToolBar.replyText == nil ? nil : replyToComment


        guard textToolBar.isValidContent, let activityPresenter = activityPresenter else {
            return
        }

        textToolBar.textView.isEditable = false

        activityPresenter.reactionPresenter.addComment(for: activityPresenter.activity,
                                                       parentReaction: parentReaction,
                                                       extraData: ReactionExtraData.comment(textToolBar.text),
                                                       userTypeOf: T.ActorType.self) { [weak self] in
            if let self = self {
                self.textToolBar.text = ""
                self.textToolBar.updateTextHeightIfNeeded()
                self.textToolBar.textView.isEditable = true

                if let error = $0.error {
                    self.logErrorAction?("[Post Details] Something went wrong when add feed comment",
                                         "feedID: \(activityPresenter.activity.id), error: \(error.localizedDescription)")
                } else {
                    self.reloadComments(isNewCommentSent: true)
                }
            }
        }
    }
}

// MARK: - Modally presented

extension DetailViewController {
    /// Setup the close button on the navigation bar, when the view controller modally presented.
    open func setupNavigationBarForModallyPresented() {
        guard navigationController != nil else {
            return
        }

        let closeButton = UIButton(type: .custom)
        closeButton.setImage(UIImage(named: "close_icon"), for: .normal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)

        closeButton.addTap { [weak self] _ in
            self?.dismiss(animated: true)
        }
    }
}

extension DetailViewController {
    private func loadActivityByID() {
        guard let activityId = activityId, let currentUserId = currentUserId else { return }
        refreshControl.beginRefreshing()
        Client.feedSharedClient.get(typeOf: Activity.self, activityIds: [activityId]) { [weak self] result in
            guard let self else { return }
            do {
                let response = try result.get()
                guard let userActivityWithReactionsCount = response.results.first else {
                    return
                }
                self.updateActivity(userActivityWithReactionsCount, currentUserId: currentUserId)
            } catch let responseError {
                self.handleError(error: responseError)
            }
        }
    }

    private func updateActivity(_ activity: Activity, currentUserId: String) {
        guard let activity = activity as? T else {
            self.feedLoadingCompletion?(NSError(domain: "Failed to cast activity to expected type \(T.self)", code: 0))
            return
        }
        let reactionPresenter = ReactionPresenter()
        let activityPresenter: ActivityPresenter<T> = ActivityPresenter(activity: activity, reactionPresenter: reactionPresenter, reactionTypes: [.comments, .likes], timelineVideoEnabled: timelineVideoEnabled)
        self.activityPresenter = activityPresenter
        self.isCurrentUser = activity.actor.id == currentUserId
        self.feedLoadingCompletion?(nil)
        DispatchQueue.mainAsyncIfNeeded { [weak self] in
            self?.reloadComments()
        }
    }

    private func handleError(error: Error) {
        self.refreshControl.endRefreshing()
        self.feedLoadingCompletion?(error)
    }
}
