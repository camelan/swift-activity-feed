import UIKit
import GetStream
import Kingfisher

public struct StreamFeedUIKitIOS {
    public static var flatFeed: FlatFeed?
    private static var flatFeedPresenter: FlatFeedPresenter<Activity>?
    private static var subscriptionId: SubscriptionId?
    public static var notificationFeed: NotificationFeed?
    public static var getNotificationFeed: NotificationFeed?
    private static var notificationFeedPresenter: NotificationsPresenter<EnrichedActivity<User, String, DefaultReaction>>?
    private static var notificationSubscriptionId: SubscriptionId?

    public static func makeTimeLineVC(entryPoint: GetStreamFeedEntryPoint = .timeline,
                                      feedSlug: String,
                                      userId: String,
                                      isCurrentUser: Bool,
                                      pageSize: Int,
                                      localizedNavigationTitle: String,
                                      autoLikeEnabled: Bool,
                                      timelineVideoEnabled: Bool,
                                      reportUserAction: @escaping ((String, String) -> Void),
                                      shareTimeLinePostAction:  @escaping ((String?) -> Void),
                                      navigateToUserProfileAction: @escaping ((String) -> Void),
                                      navigateToPostDetails: @escaping ((String) -> Void),
                                      logErrorAction: @escaping ((String, String) -> Void)) -> ActivityFeedViewController {
        let timeLineVC = ActivityFeedViewController.fromBundledStoryboard()
        timeLineVC.isCurrentUser = isCurrentUser
        timeLineVC.autoLikeEnabled = autoLikeEnabled
        timeLineVC.timelineVideoEnabled = timelineVideoEnabled
        timeLineVC.localizedNavigationTitle = localizedNavigationTitle
        timeLineVC.pageSize = pageSize
        timeLineVC.entryPoint = entryPoint
        timeLineVC.reportUserAction = reportUserAction
        timeLineVC.shareTimeLinePostAction = shareTimeLinePostAction
        timeLineVC.navigateToUserProfileAction = navigateToUserProfileAction
        timeLineVC.navigateToPostDetails = navigateToPostDetails
        timeLineVC.logErrorAction = logErrorAction
        timeLineVC.modalPresentationStyle = .fullScreen
        let nav = UINavigationController(rootViewController: timeLineVC)
        nav.modalPresentationStyle = .fullScreen
        let flatFeed = Client.feedSharedClient.flatFeed(feedSlug: feedSlug, userId: userId)
        let presenter = FlatFeedPresenter<Activity>(flatFeed: flatFeed,
                                                    reactionTypes: [.likes, .comments], timelineVideoEnabled: timelineVideoEnabled)

        timeLineVC.presenter = presenter

        return nav.viewControllers.first as! ActivityFeedViewController
    }


    public static func makeEditPostVC(petId: String? = nil,
                                      imageCompression: Double,
                                      videoCompression: Int,
                                      videoMaximumDurationInMinutes: Double,
                                      timeLineVideoEnabled: Bool,
                                      onPostComplete: @escaping (() -> Void),
                                      alertRequiredPermissions: @escaping (() -> Void),
                                      logErrorAction: @escaping ((String, String) -> Void)) -> EditPostViewController {
        guard let userFeedId: FeedId = FeedId(feedSlug: "user",
                                              client: Client.feedSharedClient) else { return EditPostViewController() }
        let editPostViewController = EditPostViewController.fromBundledStoryboard()
        editPostViewController.presenter = EditPostPresenter(flatFeed: Client.feedSharedClient.flatFeed(userFeedId),
                                                             view: editPostViewController,
                                                             petId: petId,
                                                             imageCompression: imageCompression,
                                                             videoMaximumDurationInMinutes: videoMaximumDurationInMinutes,
                                                             videoCompression: videoCompression,
                                                             timeLineVideoEnabled: timeLineVideoEnabled,
                                                             logErrorAction: logErrorAction)
        editPostViewController.onPostComplete = onPostComplete
        editPostViewController.alertRequiredPremissions = alertRequiredPermissions
        editPostViewController.modalPresentationStyle = .fullScreen
        return editPostViewController
    }

    public static func makePostDetailsVC(with activityId: String,
                                         currentUserId: String,
                                         autoLikeEnabled: Bool,
                                         timelineVideoEnabled: Bool,
                                         reportUserAction: @escaping ((String, String) -> Void),
                                         shareTimeLinePostAction:  @escaping ((String?) -> Void),
                                         navigateToUserProfileAction: @escaping ((String) -> Void),
                                         feedLoadingCompletion: @escaping ((Error?) -> Void),
                                         logErrorAction: @escaping ((String, String) -> Void)) -> PostDetailTableViewController {

        let activityDetailTableViewController = PostDetailTableViewController()
        guard let flatFeed = Client.feedSharedClient.flatFeed(feedSlug: "user") else { return PostDetailTableViewController() }
        let flatFeedPresenter = FlatFeedPresenter<Activity>(flatFeed: flatFeed,
                                                            reactionTypes: [.comments, .likes])

        activityDetailTableViewController.reportUserAction = reportUserAction
        activityDetailTableViewController.shareTimeLinePostAction = shareTimeLinePostAction
        activityDetailTableViewController.navigateToUserProfileAction = navigateToUserProfileAction
        activityDetailTableViewController.logErrorAction = logErrorAction
        activityDetailTableViewController.autoLikeEnabled = autoLikeEnabled
        activityDetailTableViewController.timelineVideoEnabled = timelineVideoEnabled
        activityDetailTableViewController.presenter = flatFeedPresenter
        activityDetailTableViewController.currentUserId = currentUserId
        activityDetailTableViewController.activityId = activityId
        activityDetailTableViewController.feedLoadingCompletion = feedLoadingCompletion
        activityDetailTableViewController.sections = [.activity, .comments]

        return activityDetailTableViewController
    }

    public static func setupFeedStream(baseURL: URL, apiKey: String, appId: String, region: BaseURL.Location, logsEnabled: Bool = true) {
        if Client.feedSharedClient.token.isEmpty {
            Client.feedSharedClient = Client(apiKey: apiKey,
                                   appId: appId,
                                   baseURL: BaseURL(customURL: baseURL),
                                   logsEnabled: logsEnabled)
        }
        
        Client.feedConfig = .init(apiKey: apiKey, appId: appId, baseURL: BaseURL(customURL: baseURL), logsEnabled: logsEnabled)
        UIFont.overrideInitialize()
        KingfisherManager.shared.downloader.downloadTimeout = 600
    }
    
    public static func setupNotificationStream(baseURL: URL, apiKey: String, appId: String, region: BaseURL.Location, logsEnabled: Bool = true) {
        if Client.notificationSharedClient.token.isEmpty {
            Client.notificationSharedClient = Client(apiKey: apiKey,
                                   appId: appId,
                                   baseURL: BaseURL(customURL: baseURL),
                                   logsEnabled: logsEnabled)
        }
        
        Client.notificationConfig = .init(apiKey: apiKey, appId: appId, baseURL: BaseURL(customURL: baseURL), logsEnabled: logsEnabled)
        UIFont.overrideInitialize()
        KingfisherManager.shared.downloader.downloadTimeout = 600
    }


    public static func logOut() {
        Client.feedSharedClient = Client(apiKey: "", appId: "")
        Client.notificationSharedClient = Client(apiKey: "", appId: "")
        Client.feedSharedClient.currentUser = nil
        Client.notificationSharedClient.currentUser = nil
        Client.feedSharedClient.currentUserId = nil
        Client.notificationSharedClient.currentUserId = nil
        Client.feedSharedClient.token = ""
        Client.notificationSharedClient.token = ""
    }

    public static func createUser(userId: String, displayName: String, profileImage: String, completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.feedSharedClient.create(user: customUser, getOrCreate: true) { result in
            do {
                let retrivedUser = try result.get()
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }


    public static func updateUser(userId: String, displayName: String, profileImage: String, completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.feedSharedClient.update(user: customUser) { result in
            do {
                let retrivedUser = try result.get()
                var currentUser = Client.feedSharedClient.currentUser as? User
                if !profileImage.isEmpty {
                    currentUser?.avatarURL = URL(string: profileImage)!
                }
                if !displayName.isEmpty {
                    currentUser?.name = displayName
                }
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public static func registerFeedUser(withToken token: String,
                                        userId: String,
                                        displayName: String,
                                        profileImage: String,
                                        completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.feedSharedClient.setupUser(customUser, token: token) { result in
            do {
                let retrivedUser = try result.get()
                let currentUser = Client.feedSharedClient.currentUser as? User
                if !profileImage.isEmpty {
                    currentUser?.avatarURL = URL(string: profileImage)!
                }
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
    
    public static func registerNotificationUser(withToken token: String, userId: String, displayName: String, profileImage: String, completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.notificationSharedClient.setupUser(customUser, token: token) { result in
            do {
                let retrivedUser = try result.get()
                let currentUser = Client.notificationSharedClient.currentUser as? User
                if !profileImage.isEmpty {
                    currentUser?.avatarURL = URL(string: profileImage)!
                }
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

}

// MARK: - Following Feed
extension StreamFeedUIKitIOS {
    public static func subscribeForFeedsUpdates(feedSlug: String,
                                                userId: String,
                                                logErrorAction: ((String, String) -> Void)?,
                                                onFeedsUpdate: @escaping ((Result<SubscriptionResponse<Activity>, SubscriptionError>) -> Void)) {
        let feedID = FeedId(feedSlug: feedSlug, userId: userId)
        let flatFeed = FlatFeed(feedID)
        StreamFeedUIKitIOS.flatFeedPresenter = FlatFeedPresenter<Activity>(flatFeed: flatFeed, reactionTypes: [.comments, .likes])

        StreamFeedUIKitIOS.subscriptionId = StreamFeedUIKitIOS.flatFeedPresenter?.subscriptionPresenter.subscribe(clientType: Client.feedSharedClient, { result in
            onFeedsUpdate(result)
        }, logErrorAction: logErrorAction)

    }

    public static func unsubscribeFromFeedUpdates() {
        StreamFeedUIKitIOS.subscriptionId = nil
    }

    public static func loadFollowingFeeds(feedSlug: String, userId: String, pageSize: Int, completion: @escaping (Result<[Activity], Error>) -> Void) {
        let feedID = FeedId(feedSlug: feedSlug, userId: userId)
        StreamFeedUIKitIOS.flatFeed = FlatFeed(feedID)
        StreamFeedUIKitIOS.flatFeed?.get(typeOf: Activity.self, pagination: .limit(pageSize), includeReactions: [.counts, .own, .latest], completion: { result in
            do {
                let response = try result.get()
                let activites = response.results
                completion(.success(activites))
            } catch let responseError {
                completion(.failure(responseError))
            }
        })
    }
}

// MARK: - Notification Center
extension StreamFeedUIKitIOS {
    public static func subscribeForNotificationsUpdates(userId: String,
                                                        logErrorAction: ((String, String) -> Void)?,
                                                        onFeedsUpdate: @escaping (Result<[EnrichedActivity<User, String, DefaultReaction>], Error>) -> Void) {
        let feedID = FeedId(feedSlug: "notification", userId: userId)
        let notificationFeed = NotificationFeed(feedID)
        StreamFeedUIKitIOS.notificationFeedPresenter = NotificationsPresenter<EnrichedActivity<User, String, DefaultReaction>>(notificationFeed)
        
        StreamFeedUIKitIOS.notificationSubscriptionId = StreamFeedUIKitIOS.notificationFeedPresenter?.subscriptionPresenter.subscribe(clientType: Client.notificationSharedClient, { result in
            do {
                let response = try result.get()
                let newActivites = response.newActivities
                onFeedsUpdate(.success(newActivites) )
            } catch let responseError {
                onFeedsUpdate(.failure(responseError))
            }
        }, logErrorAction: logErrorAction)
    }

    public static func unsubscribeFromNotificationsUpdates() {
        StreamFeedUIKitIOS.notificationSubscriptionId = nil
        StreamFeedUIKitIOS.notificationFeed = nil
    }

    public static func loadNotifications(userId: String,
                                         lastId: String?,
                                         pageSize: Int,
                                         completion: @escaping (Result<([NotificationGroup<GetStream.EnrichedActivity<User, String, DefaultReaction>>], Int), Error>) -> Void) {
        let feedID = FeedId(feedSlug: "notification", userId: userId)
        let pagination: Pagination = lastId == nil ? .limit(pageSize) : (.limit(pageSize) + .lessThan(lastId ?? ""))
        StreamFeedUIKitIOS.getNotificationFeed = NotificationFeed(feedID)

        StreamFeedUIKitIOS.getNotificationFeed?.get(typeOf: GetStream.EnrichedActivity<User, String, DefaultReaction>.self,
                                                 enrich: true,
                                                 pagination: pagination,
                                                 markOption: .none) { result in
            do {
                let response = try result.get()
                let unSeenCount = response.unseenCount ?? 0
                let activites = response.results

                completion(.success((activites, unSeenCount)))
            } catch let responseError {
                completion(.failure(responseError))
            }
        }
    }

    public static func markAsRead(userId: String,
                                  notificationId: String, completion: @escaping (Error?) -> Void) {
        let feedID = FeedId(feedSlug: "notification", userId: userId)
        StreamFeedUIKitIOS.notificationFeed = NotificationFeed(feedID)
        StreamFeedUIKitIOS.notificationFeed?.get(typeOf: GetStream.EnrichedActivity<String, String, DefaultReaction>.self,
                                                 enrich: false,
                                                 markOption: .read([notificationId])) { result in
            completion(result.error)
        }
    }

    public static func markAllAsSeen(userId: String,
                                     completion: @escaping (Error?) -> Void) {
        let feedID = FeedId(feedSlug: "notification", userId: userId)
        StreamFeedUIKitIOS.notificationFeed = NotificationFeed(feedID)
        StreamFeedUIKitIOS.notificationFeed?.get(typeOf: GetStream.EnrichedActivity<String, String, DefaultReaction>.self,
                                                 enrich: false,
                                                 markOption: .seenAll) { result in
            completion(result.error)
        }
    }


    public static func getUnseenCount(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let feedID = FeedId(feedSlug: "notification", userId: userId)
        StreamFeedUIKitIOS.notificationFeed = NotificationFeed(feedID)
        StreamFeedUIKitIOS.notificationFeed?.get(typeOf: GetStream.EnrichedActivity<String, String, DefaultReaction>.self,
                                                 enrich: false,
                                                 markOption: .none) { result in
            do {
                let response = try result.get()
                let unSeenCount = response.unseenCount ?? 0

                completion(.success(unSeenCount))
            } catch let responseError {
                completion(.failure(responseError))
            }
        }
    }

}
