/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/// ML Model is locate at: http://ios-mlmodel.oss-cn-beijing.aliyuncs.com/GoogLeNetPlaces.mlmodel

import UIKit
import Vision
import ImageIO

class ImageViewController: UIViewController {

  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var annotationView: AnnotationLayer!

  var image: UIImage! {
    didSet {
      imageView?.image = image
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.largeTitleDisplayMode = .never

    imageView.image = image
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Vision work on image date, a pixel buffer, CIImage or CGImage
    guard let cgImage = image.cgImage else {
        print("can't create CIImage from UIImage")
        return
    }
    // Makes sure the detected bounds line up in the same direction as the image
    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    // Create face detection request
    let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaces)
    // Process one or more requests for a single image
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
    // Vision request can be time intensive, perform them on a background queue
    DispatchQueue.global(qos: .userInteractive).async {
        do {
            // Perform detection work
            try handler.perform([faceRequest])
        } catch {
            print("Error handling vision request \(error)")
        }
    }
    
  }

  func handleFaces(request: VNRequest, error: Error?) {
    
    guard let observations = request.results as? [VNFaceObservation] else {
        print("unexpected result type from face request")
        return
    }
    
    DispatchQueue.main.async {
        self.handleFaces(observations: observations)
    }
  }
    
    func handleFaces(observations: [VNFaceObservation]) {
        var faces: [FaceDimensions] = []
        
        let viewSize = imageView.bounds.size
        let imageSize = image.size
        
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let scaledRatio = min(widthRatio, heightRatio)
        
        let scaleTransform = CGAffineTransform(scaleX: scaledRatio, y: scaledRatio)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let imageX = (viewSize.width - scaledImageSize.width) / 2
        let imageY = (viewSize.height - scaledImageSize.height) / 2
        let imageLocationTransform = CGAffineTransform(scaleX: imageX, y: imageY)
        let uiTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -imageSize.height)
        
        for face in observations {
            // Translate each observation's coordinates to imageView coordinates
            let observedFaceBox = face.boundingBox
            // an observation’s boundingBox is normalized in Core Graphics coordinates, with an origin at the bottom left.
            // Denormalize it to the input image size.
            // Flip it into UIKit coordinates.
            // Scale it to the drawn aspect ratio.
            // Translate it to where the image is within the image view.
            let faceBox = observedFaceBox.scaled(to: imageSize)
                                         .applying(uiTransform)
                                         .applying(scaleTransform)
                                         .applying(imageLocationTransform)
            // Encapsulate the face bounds in a custom struct.
            let face = FaceDimensions(faceRect: faceBox)
            faces.append(face)
        }
        // Add all face dimensions to annotationView to draw custom images over original photo
        annotationView.faces = faces
        annotationView.setNeedsDisplay()
    }
}
