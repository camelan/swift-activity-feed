//
//  EditPostViewController.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 25/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import GetStream
import Nuke
import Combine

enum EditTimelinePostEntryPoint {
    case editPost
    case newPost
}
public final class EditPostViewController: UIViewController, BundledStoryboardLoadable {
    public static var storyboardName = "ActivityFeed"
    private static let textViewPlaceholder = NSAttributedString(string: "Share something...")
    let activityIndicator = UIActivityIndicatorView(style: .medium)
    lazy var permissionsPresenter = PermissionsPresenter(delegate: self)
    var presenter: EditPostPresenter?
    var entryPoint: EditTimelinePostEntryPoint = .newPost
    var keyboardIsShown: Bool = false
    var compressedVideosCount = 0
    var uploadedMediaCount = 0
    var mediaPickerManager: MediaPicker?
    var onPostComplete: (() -> Void)?
    var alertRequiredPremissions: (() -> Void)?
    
    private var bag = Set<AnyCancellable>()
    let progressView = UIProgressView()
    var alertView: CustomProgressAlertView?
    @IBOutlet weak var activityIndicatorBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var galleryStackView: UIStackView!
    @IBOutlet weak var uploadImageStackView: UIStackView!
    @IBOutlet weak var galleryStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var avatarView: AvatarView!
    @IBOutlet weak var topMainView: UIView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addImageBtn: UIButton!
    @IBOutlet weak var addImageTextBtn: UIButton!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    weak var postBtn: UIButton? {
        let btn = UIButton(frame: CGRect(origin: .zero, size: CGSize(width: 78, height: 40)))
        btn.backgroundColor = UIColor(red: 95/255, green: 65/255, blue: 224/255, alpha: 1)
        let postButtonTitle = entryPoint == .editPost ? "Update" : "Post"
        btn.setTitle(postButtonTitle, for: .normal)
        btn.titleLabel?.font = UIFont(name: "GTWalsheimProRegular", size: 16.0)!
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(postBtnPressed(_:)), for: .touchUpInside)
        return btn
    }
    
    weak var backBtn: UIBarButtonItem? {
        let image = UIImage(named: "backArrow")
        let desiredImage = image
        let back = UIBarButtonItem(image: desiredImage, style: .plain, target: self, action: #selector(backBtnPressed(_:)))
        return back
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setButtonText()
        setupUserData()
        setupTextView()
        setupTableView()
        setupCollectionView()
        activityIndicatorBarButtonItem.customView = activityIndicator
        hideKeyboardWhenTappedAround()
        keyboardBinding()
        addImageBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addImage)))
        addImageTextBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addImageTextTapped)))
        setupNavigationBarItems()
        topMainView.frame.size.height = tableView.frame.height - galleryStackView.frame.height
        setPostData()
        setupAlertView()
        bind()
    }
    
    private func setButtonText() {
        let buttonTitle = presenter?.timeLineVideoEnabled ?? false ? "Photo/Video library" : "Photo library"
        addImageTextBtn.setTitle(buttonTitle, for: .normal)
    }
    
    private func bind() {
        presenter?.videoCompressionSubject
            .dropFirst()
            .sink { [weak self] compressionResult in
                guard let self = self else { return }
                switch compressionResult {
                case .onSuccess(_):
                    break
                case .onStart:
                    guard let uploadedVideosItems = presenter?.mediaItems.filter({ $0.mediaType == .video }), uploadedVideosItems.count > 0 else { return }
                    self.compressedVideosCount += 1
                    self.showAlertWithProgressView()
                case .onCancelled, .onFailure(_):
                    self.dismiss(animated: true)
                
                }
            }
            .store(in: &bag)
        
        presenter?.filesProgressSubject
            .dropFirst()
            .sink(receiveValue: { [weak self] uploadStatus in
                guard let self else { return }
                switch uploadStatus {
                case .onStart:
                    showMediaUploadProgressView(progress: 0.0)
                    uploadedMediaCount += 1
                    if uploadedMediaCount == 1 && compressedVideosCount == 0 {
                        presentProgressView()
                    }
                case .Uploading(let progress):
                    self.showMediaUploadProgressView(progress: progress)
                case .Uploaded, .Error, .Cancelled:
                    self.dismissProgressView()
                }
            }).store(in: &bag)
    }
    
    private func showAlertWithProgressView() {
        guard let uploadedVideosItems = presenter?.mediaItems.filter({ $0.mediaType == .video }), uploadedVideosItems.count > 0 else { return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if compressedVideosCount == 1 {
                presentProgressView()
            }
            let progressPrecentage = Float(self.compressedVideosCount) / Float(uploadedVideosItems.count)
            self.alertView?.titleLbl.text = "\("Preparing videos") [\(self.compressedVideosCount)/\(uploadedVideosItems.count)]"
            self.alertView?.progressLbl.text = "\(Int(progressPrecentage * 100))%"
            self.alertView?.progressView.setProgress(progressPrecentage, animated: true)
        }
    }
    
    private func showMediaUploadProgressView(progress: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let mediaCount = presenter?.mediaItems.count ?? 0
            let uploadedCount = (presenter?.uploadedFilesCount ?? 0) + 1
            let filesString = (mediaCount > 1) ? "Files" : "File"
            self.alertView?.titleLbl.text = "Uploading Media \(filesString): \(uploadedCount)/\(mediaCount)"
            self.alertView?.progressLbl.text = "\(Int(progress * 100))%"
            self.alertView?.progressView.tintColor = view.tintColor
            self.alertView?.progressView.setProgress(Float(progress), animated: false)
        }
    }
    
    private func setupAlertView() {
        self.alertView = CustomProgressAlertView.instantiate()
        self.alertView?.cancel = { [weak self] in
            guard let self = self else { return }
            self.presenter?.compressionCanceled = true
            self.presenter?.uploadTask?.cancel()
            self.dismiss(animated: true)
        }
    }
    
    func layoutAlertView() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.transitionCrossDissolve]) { [weak self] in
            guard let self = self else { return }
            guard let alert = self.alertView else {
                return
            }
            alert.frame = CGRect(
                origin: .zero,
                size: CGSize(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
            )
            if let topView = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                topView.addSubview(alert)
            } else {
                self.view.addSubview(alert)
            }
        }
    }
    
    deinit {
        alertView = nil
    }
    
    private func presentProgressView() {
        DispatchQueue.main.async { [weak self] in
            self?.layoutAlertView()
        }
    }
    
    private func dismissProgressView() {
        DispatchQueue.main.async { [weak self] in
            self?.alertView?.removeFromSuperview()
        }
    }
    
    private func setPostData() {
        guard let activity = presenter?.activity, entryPoint == .editPost else {
            return
        }
        let activityObject = activity.object
        switch activityObject {
        case .text(let text):
            textView.text = text
        case .image(let url):
            // updatePhoto(with: url)
            break
        default:
            return
        }
    
        navigationItem.title = "EDIT POST"
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.hideHairline()
    }
    
    private func setupNavigationBarItems() {
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: postBtn!), activityIndicatorBarButtonItem]
        navigationItem.leftBarButtonItem = backBtn
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.customView?.alpha = 0.5
        navigationController?.navigationBar.setCustomTitleFont(font: UIFont(name: "GTWalsheimProBold", size: 18.0)!)
    }
    
    @objc private func backBtnPressed(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        
        if entryPoint == .editPost {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func postBtnPressed(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        activityIndicator.startAnimating()
        sender.isEnabled = false
        
        if entryPoint == .editPost {
            presenter?.updateActivity(with: textView.text)
        } else {
            Task {
                await presenter?.save(validatedText()) { [weak self] error in
                    guard let self = self else {
                        return
                    }
                    
                    self.activityIndicator.stopAnimating()
                    
                    if let error = error {
                        // self.showErrorAlert(error)
                    } else {
                        self.onPostComplete?()
                        backBtnPressed(UIBarButtonItem())
                    }
                }
            }
        }
    }
    
    private func keyboardBinding(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        if keyboardIsShown {
            return
        }
        
        keyboardIsShown = true
        galleryStackViewBottomConstraint.constant -= keyboardFrame.height - view.safeAreaInset.bottom
        topMainView.frame.size.height = tableView.frame.height - keyboardFrame.height - galleryStackView.frame.height + view.safeAreaInset.bottom
        topMainView.layoutIfNeeded()
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        keyboardIsShown = false
        galleryStackViewBottomConstraint.constant = 0
        topMainView.frame.size.height = tableView.frame.height - galleryStackView.frame.height + view.safeAreaInset.bottom
        topMainView.layoutIfNeeded()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        collectionView.isHidden = false
    }
    
    @objc func addImage() {
        addImageAction()
    }
    
    @objc func addImageTextTapped() {
        addImageAction()
    }
    
    private func addImageAction() {
        view.endEditing(true)
        let timeLineVideoEnabled = presenter?.timeLineVideoEnabled ?? false
        let alertTitle = timeLineVideoEnabled ? "Add a photo/video" : "Add a photo"
        let alertBody = timeLineVideoEnabled ? "Select a photo/video source" : "Select a photo source"
        let actionTitle = timeLineVideoEnabled ? "Photo/Video library" : "Photo library"
        
        let alert = UIAlertController(title: alertTitle, message: alertBody, preferredStyle: .actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
                self?.presentGalleryMediaPicker()
            }))
        } else {
            presenter?.logErrorAction?("Photo/Video library source is not available.", "")
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
                self?.presentCameraMediaPicker()
            }))
        } else {
            presenter?.logErrorAction?("Camera source is not available.", "")
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
        
        present(alert, animated: true)
    }
    
    private func presentGalleryMediaPicker() {
        mediaPickerManager = makeMediaPicker()
        mediaPickerManager?.openGallery()
    }
    
    private func presentCameraMediaPicker() {
        guard checkPermissions() else {
            if permissionsPresenter.givenPermissions.contains(.camera) == false {
                permissionsPresenter.requestCameraAccess()
            } else if permissionsPresenter.givenPermissions.contains(.microphone) == false {
                permissionsPresenter.requestMicrophoneAccess()
            }
            return }
        permissionsPresenter.givenPermissions.removeAll()
        permissionsPresenter.deniedPermissions.removeAll()
        openCamera()
    }
    
    private func openCamera() {
        mediaPickerManager = makeMediaPicker()
        mediaPickerManager?.openCamera()
    }
    
    private func checkPermissions() -> Bool {
        permissionsPresenter.checkAllPermissions()
        if permissionsPresenter.givenPermissions.contains(.camera),
           permissionsPresenter.givenPermissions.contains(.microphone) {
            return true
        } else {
            return false
        }
    }
    
    private func makeMediaPicker() -> MediaPicker {
        let timelineVideoEnabled = presenter?.timeLineVideoEnabled ?? false
        let videoMaximumDurationInMinutes = presenter?.videoMaximumDurationInMinutes ?? 2.0
        let logErrorAction = presenter?.logErrorAction
        let mediaPicker = MediaPicker(presentationController: self,
                                         delegate: self,
                                         videoMaximumDurationInMinutes: videoMaximumDurationInMinutes,
                                         timelineVideoEnabled: timelineVideoEnabled,
                                         logErrorAction: logErrorAction)
        mediaPicker.showAlertWithErrorMsgAction = { [weak self] errorMsg in
            self?.showAlertWith(message: errorMsg)
        }
        
        return mediaPicker
    }
    
    private func showAlertWith(message: String) {
        let okAction: AlertAction = ("Ok", .cancel, {}, true)
        
        DispatchQueue.mainAsyncIfNeeded { [weak self] in
            self?.alertWithAction(title: "Error", message: message, alertStyle: .alert, tintColor: nil, actions: [okAction])
        }
    }
    
    private func handlePickedMedia(mediaItems: [MediaItem]) {
        guard let firstItem = mediaItems.first else { return }
        self.presenter?.mediaItems.insert(firstItem, at: 0)
        self.updateCollectionView()
        self.checkUploadedImageLimit()
    }
    
    private func checkUploadedImageLimit() {
        let maximumLimit = self.presenter?.mediaItems.count ?? 0 >= 6
        self.uploadImageStackView.isUserInteractionEnabled = maximumLimit ? false : true
        self.uploadImageStackView.alpha = maximumLimit ? 0.5 : 1.0
    }
    
    private func removeSelectedMediaItem(at indexPath: IndexPath) {
        if let presenter = presenter, indexPath.item < presenter.mediaItems.count {
            presenter.mediaItems.remove(at: indexPath.item)
            updateCollectionView()
        }
    }
    
    @objc func done() {
        view.endEditing(true)
    }
    
    private func setupUserData() {
        userNameLabel.text = User.current?.name
        loadAvatar()
    }
    
    private func loadAvatar() {
        avatarView.imageURL = User.current?.avatarURL?.absoluteString
    }
    
    private func updateSaveButtonEnabling() {
        guard let presenter = presenter else {
            return
        }
        navigationItem.rightBarButtonItem?.isEnabled = presenter.mediaItems.count > 0 || validatedText() != nil
        navigationItem.rightBarButtonItem?.customView?.alpha = presenter.mediaItems.count > 0 || validatedText() != nil ? 1 : 0.5
    }
}

// MARK: - Edit Post Viewable

extension EditPostViewController: EditPostViewable {
    
    public func underlineLinks(with dataDetectorURLItems: [DataDetectorURLItem]) {
        textView.attributedText = textView.attributedText.string
            .attributedString { attributedString in
                dataDetectorURLItems.forEach { item in
                    attributedString.addAttributes([.backgroundColor: Appearance.Color.transparentBlue2],
                                                   range: attributedString.string.nsRange(from: item.range))
                }
            }
            .applyedFont(UIFont(name: "GTWalsheimProRegular", size: 14.0)!)
    }
    
    public func updateOpenGraphData() {
        tableView.reloadData()
    }
}

// MARK: - Text View

extension EditPostViewController: UITextViewDelegate {
    
    func setupTextView() {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))]
        textView.inputAccessoryView = toolbar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.textView.becomeFirstResponder()
        }
    }
    
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if textView.attributedText.string == EditPostViewController.textViewPlaceholder.string {
            textView.attributedText = NSAttributedString(string: "").applyedFont(UIFont(name: "GTWalsheimProRegular", size: 14.0)!)
        }
        
        return true
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        updateSaveButtonEnabling()
        
        if let text = validatedText() {
           // presenter?.dataDetectorWorker?.match(text)
        }
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        updateSaveButtonEnabling()

        if !(navigationItem.rightBarButtonItem?.isEnabled ?? false) {
            textView.attributedText = EditPostViewController.textViewPlaceholder.applyedFont(UIFont(name: "GTWalsheimProRegular", size: 14.0)!)
        }
    }
    
    private func validatedText() -> String? {
        let text = textView.attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text == EditPostViewController.textViewPlaceholder.string ? nil : text
    }
}

// MARK: - Table View

extension EditPostViewController: UITableViewDelegate, UITableViewDataSource {
    private func setupTableView() {
        tableView.estimatedRowHeight = 116
        tableView.register(UINib(nibName: "OpenGraphTableViewCell", bundle: .module), forCellReuseIdentifier: "OpenGraphTableViewCell")
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter?.ogData == nil ? 0 : 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath) as OpenGraphTableViewCell
        
        guard let ogData = presenter?.ogData else {
            return cell
        }
        
        cell.update(with: ogData)
        
        return cell
    }
}

// MARK: - Collection View

extension EditPostViewController: UICollectionViewDataSource {
    
    private func setupCollectionView() {
        collectionViewHeightConstraint.constant = 0
        collectionView.register(UINib(nibName: "AddingImageCollectionViewCell", bundle: .module), forCellWithReuseIdentifier: "AddingImageCollectionViewCell")
        collectionView.register(UINib(nibName: "VideoCell", bundle: .module), forCellWithReuseIdentifier: "VideoCell")
        collectionView.dataSource = self
    }
    
    private func updateCollectionView() {
        guard let presenter = presenter else {
            return
        }
        collectionViewHeightConstraint.constant = presenter.mediaItems.count > 0 ? AddingImageCollectionViewCell.height : 0
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
            self?.collectionView.layoutIfNeeded()
        }
        updateSaveButtonEnabling()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return presenter?.mediaItems.count ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let mediaItem = presenter?.mediaItems[indexPath.item] else { return UICollectionViewCell() }
        
        switch mediaItem.mediaType {
        case .image:
            let imageCell = collectionView.dequeueReusableCell(for: indexPath) as AddingImageCollectionViewCell
            guard let selectedImage = mediaItem.image else {
                return imageCell
            }
            imageCell.removeButton.addTap { [weak self] _ in
                guard let self else { return }
                self.removeSelectedMediaItem(at: indexPath)
                self.checkUploadedImageLimit()
            }
            imageCell.setImage(image: selectedImage)
            
            return imageCell
        case .video:
            let videoCell = collectionView.dequeueReusableCell(for: indexPath) as VideoCell
            videoCell.config(thumbnailImage: mediaItem.videoThumbnail)
            videoCell.removeButton.addTap { [weak self] _ in
                guard let self else { return }
                self.removeSelectedMediaItem(at: indexPath)
                self.checkUploadedImageLimit()
            }
            return videoCell
        }
    }
}
extension EditPostViewController: PHImagePickerDelegate {
    func didSelect(mediaItems: [MediaItem]) {
        handlePickedMedia(mediaItems: mediaItems)
    }
}


extension EditPostViewController: PermissionsDelegate {
    func didCheckCameraPermission(_ granted: Bool) {
        if granted == true {
            if permissionsPresenter.givenPermissions.contains(.microphone) == false && permissionsPresenter.deniedPermissions.contains(.microphone) == false {
                permissionsPresenter.requestMicrophoneAccess()
            }
        }
    }
    
    func didDenyPermissionBefore() {
        alertRequiredPremissions?()
    }
    
    func hasEnabledAllPermissions() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.openCamera()
        }
    }
}
