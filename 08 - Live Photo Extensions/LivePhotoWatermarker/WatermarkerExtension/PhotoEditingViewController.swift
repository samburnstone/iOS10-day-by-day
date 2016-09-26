//
//  PhotoEditingViewController.swift
//  WatermarkerExtension
//
//  Created by Samuel Burnstone on 26/09/2016.
//  Copyright © 2016 ShinobiControls. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

class PhotoEditingViewController: UIViewController, PHContentEditingController {

    var input: PHContentEditingInput!
    
    lazy var livePhotoContext: PHLivePhotoEditingContext = {
        return PHLivePhotoEditingContext(livePhotoEditingInput: self.input)!
    }()
    
    @IBOutlet weak var photoView: PHLivePhotoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        photoView.contentMode = .scaleAspectFit
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - PHContentEditingController
    
    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        // Inspect the adjustmentData to determine whether your extension can work with past edits.
        // (Typically, you use its formatIdentifier and formatVersion properties to do this.)
        return false
    }
    
    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        // Present content for editing, and keep the contentEditingInput for use when closing the edit session.
        // If you returned true from canHandleAdjustmentData:, contentEditingInput has the original image and adjustment data.
        // If you returned false, the contentEditingInput has past edits "baked in".
        
        if contentEditingInput.mediaType == .image && contentEditingInput.mediaSubtypes.contains(.photoLive) {
            photoView.livePhoto = contentEditingInput.livePhoto
        }
        
        // Store the input so we can access it later and create our editing context
        input = contentEditingInput
        
        applyBlur()
    }
    
    func finishContentEditing(completionHandler: @escaping ((PHContentEditingOutput?) -> Void)) {
        
        let output = PHContentEditingOutput(contentEditingInput: self.input!)
        
        livePhotoContext.saveLivePhoto(to: output) {
            success, error in
            if success {
                completionHandler(output)
            }
            else {
                print("There was a problem saving the photo :(")
            }
        }
        
    }
    
    var shouldShowCancelConfirmation: Bool {
        // Determines whether a confirmation to discard changes should be shown to the user on cancel.
        // (Typically, this should be "true" if there are any unsaved changes.)
        return false
    }
    
    func cancelContentEditing() {
        // Clean up temporary files, etc.
        // May be called after finishContentEditingWithCompletionHandler: while you prepare output.
    }
}

extension PhotoEditingViewController {
    
    func applyBlur() {
        let blurLevel: CGFloat = 10
        
        let timeOfStillPhoto = CMTimeGetSeconds(livePhotoContext.photoTime)
        let duration = CMTimeGetSeconds(livePhotoContext.duration)
        
        livePhotoContext.frameProcessor = {
            [unowned self]
            frame, error in
            
            let normalizedFrameTime = self.normalizedTimeInterval(for: frame,
                                                                  withDuration: duration,
                                                                  withTimeOfStillPhoto: timeOfStillPhoto)
            
            let blurLevel = fabs(normalizedFrameTime) * blurLevel
            
            print(time)
            
            return frame.image.applyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey : blurLevel])
        }
        
        updateLivePhotoView()
    }
    
    private func updateLivePhotoView() {
        let size = input!.displaySizeImage!.size
        livePhotoContext.prepareLivePhotoForPlayback(withTargetSize: size, options: nil) {
            [weak self]
            livePhoto, error in
            self?.photoView.livePhoto = livePhoto
        }
    }
    
    private func normalizedTimeInterval(for frame: PHLivePhotoFrame,
                                        withDuration duration: Float64,
                                        withTimeOfStillPhoto timeOfStillPhoto: Float64) -> CGFloat {
        
        
        let timeOfFrame = CMTimeGetSeconds(frame.time)
        
        if timeOfFrame < timeOfStillPhoto {
            return CGFloat((timeOfFrame - timeOfStillPhoto) / timeOfStillPhoto)
        }
        return CGFloat((timeOfFrame - timeOfStillPhoto) / (duration - timeOfStillPhoto))
    }
}
