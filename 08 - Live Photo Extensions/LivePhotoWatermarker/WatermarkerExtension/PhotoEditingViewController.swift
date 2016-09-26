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

    var input: PHContentEditingInput?
    
    @IBOutlet weak var photoView: PHLivePhotoView!
    
    lazy var livePhotoContext: PHLivePhotoEditingContext = {
        return PHLivePhotoEditingContext(livePhotoEditingInput: self.input!)!
    }()
    
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
        
        input = contentEditingInput
        
        // Show alert
        requestWatermarkDetails()
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
    
    fileprivate func updateLivePhotoView() {
        let size = input!.displaySizeImage!.size
        livePhotoContext.prepareLivePhotoForPlayback(withTargetSize: size, options: nil) {
            [weak self]
            livePhoto, error in
            self?.photoView.livePhoto = livePhoto
        }

    }
}

extension PhotoEditingViewController {
    
    /// Brings up UI to allow the user to input the text they wish to watermark their photo with.
    fileprivate func requestWatermarkDetails() {
        
        let alert = UIAlertController(title: "Watermark Title", message: "What would like to scrawl over your lovely photo?", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: {
            textfield in
            textfield.placeholder = "John Appleseed"
        })
        
        // On cancellation, simply dimiss the extension
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        let watermarkAction = UIAlertAction(title: "Add", style: .default) {
            [weak self]
            _ in
            guard let watermarkText = alert.textFields?[0].text else { return }
            
            let prefixedWatermarkText = "© \(watermarkText)"
            
            self?.applyWatermark(with: prefixedWatermarkText)
            self?.updateLivePhotoView()
        }
        alert.addAction(watermarkAction)
        
        present(alert, animated: true)
    }

    
    fileprivate func applyWatermark(with title: String) {
        guard let image = UIImage.image(from: title, with: photoView.bounds.size)
            else {
                fatalError("Could not create image")
        }

        let watermarkImage = CIImage(cgImage: image.cgImage!)
        
        livePhotoContext.frameProcessor = {
            frame, _ in
            
            return frame.image.applyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: 10])
        }
    }
}

extension UIImage {
    
    /// Creates an image with the given text string.
    static func image(from text: String, with size: CGSize) -> UIImage? {
        
        // To cater for the LivePhoto zooming, we need to add a bit of padding between the text and the edge of the screen
        let insets = UIEdgeInsets(top: 0, left: 20, bottom: 20, right: 0)
        
        let font = UIFont(name: "Marker Felt", size: 40)!
        
        // Draw the text in an an image context and return it
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        let image = UIImage()
        image.draw(in: imageRect)
        
        let convertedString = text as NSString
        
        let attributes = [
            NSFontAttributeName : font,
            NSForegroundColorAttributeName : UIColor.white
        ]
        
        let textSize = convertedString.size(attributes: attributes)
        let textRect = CGRect(x: insets.left,
                              y: (size.height - insets.bottom - textSize.height),
                              width: textSize.width,
                              height: textSize.height)
        
        convertedString.draw(in: textRect, withAttributes: attributes)
        
        let textImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return textImage
    }
}
