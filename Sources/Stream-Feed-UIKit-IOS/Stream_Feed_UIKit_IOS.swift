import UIKit
import GetStream
import Kingfisher

public struct StreamFeedUIKitIOS {
    public static var flatFeed: FlatFeed?
    private static var flatFeedPresenter: FlatFeedPresenter<Activity>?
    private static var subscriptionId: SubscriptionId?

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
                                      logErrorAction: @escaping ((String, String) -> Void)) {
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
        let flatFeed = Client.shared.flatFeed(feedSlug: feedSlug, userId: userId)
        let presenter = FlatFeedPresenter<Activity>(flatFeed: flatFeed,
                                                    reactionTypes: [.likes, .comments], timelineVideoEnabled: timelineVideoEnabled)

        timeLineVC.presenter = presenter

        return nav.viewControllers.first as! ActivityFeedViewController
    }


    public static func makeEditPostVC(petId: String? = nil,
                                      imageCompression: Double,
                                      videoCompression: Int,
                                      timeLineVideoEnabled: Bool,
                                      logErrorAction: @escaping ((String, String) -> Void)) -> EditPostViewController {
        guard let userFeedId: FeedId = FeedId(feedSlug: "user") else { return EditPostViewController() }
        let editPostViewController = EditPostViewController.fromBundledStoryboard()
        editPostViewController.presenter = EditPostPresenter(flatFeed: Client.shared.flatFeed(userFeedId),
                                                             view: editPostViewController,
                                                             petId: petId,
                                                             imageCompression: imageCompression,
                                                             videoCompression: videoCompression,
                                                             timeLineVideoEnabled: timeLineVideoEnabled,
                                                             logErrorAction: logErrorAction)
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
        guard let flatFeed = Client.shared.flatFeed(feedSlug: "user") else { return PostDetailTableViewController() }
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

    public static func subscribeForFollowingFeedsUpdates(userId: String, onFollowingFeedsUpdate: @escaping (() -> Void)) {
        let feedID = FeedId(feedSlug: "following", userId: userId)
        let flatFeed = FlatFeed(feedID)
        StreamFeedUIKitIOS.flatFeedPresenter = FlatFeedPresenter<Activity>(flatFeed: flatFeed, reactionTypes: [.comments, .likes])

        StreamFeedUIKitIOS.subscriptionId = StreamFeedUIKitIOS.flatFeedPresenter?.subscriptionPresenter.subscribe({ result in
            onFollowingFeedsUpdate()
        })

    }

    public static func unsubscribeFromFeedUpdates() {
        StreamFeedUIKitIOS.subscriptionId = nil
    }

    public static func loadFollowingFeeds(userId: String, pageSize: Int, completion: @escaping (Result<[Activity], Error>) -> Void) {
        let feedID = FeedId(feedSlug: "following", userId: userId)
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

    public static func setupStream(apiKey: String, appId: String, region: BaseURL.Location, logsEnabled: Bool = true) {
        if Client.shared.token.isEmpty {
            Client.shared = Client(apiKey: apiKey,
                                   appId: appId,
                                   baseURL: BaseURL(location: region),
                                   logsEnabled: logsEnabled)
        }
        Client.config = .init(apiKey: apiKey, appId: appId, baseURL: BaseURL(location: region), logsEnabled: logsEnabled)
        UIFont.overrideInitialize()
        KingfisherManager.shared.downloader.downloadTimeout = 600
    }


    public static func logOut() {
        Client.shared = Client(apiKey: "", appId: "")
        Client.shared.currentUser = nil
        Client.shared.currentUserId = nil
        Client.shared.token = ""
    }

    public static func createUser(userId: String, displayName: String, profileImage: String, completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.shared.create(user: customUser, getOrCreate: true) { result in
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
        Client.shared.update(user: customUser) { result in
            do {
                let retrivedUser = try result.get()
                var currentUser = Client.shared.currentUser as? User
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

    public static func registerUser(withToken token: String, userId: String, displayName: String, profileImage: String, completion: @escaping ((Error?) -> Void)) {
        let customUser = User(name: displayName, id: userId, profileImage: profileImage)
        Client.shared.setupUser(customUser, token: token) { result in
            do {
                let retrivedUser = try result.get()
                let currentUser = Client.shared.currentUser as? User
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
