//
//  ContentView.swift
//  FaceTracking
//
//  Created by Nien Lam on 11/16/21.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    /*
    let uiSignal = PassthroughSubject<UISignal, Never>()
    enum UISignal {
    }
     */
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView, ARSessionDelegate {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()

    var leftEyeEntity: Entity!
    var rightEyeEntity: Entity!

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()
    }

    func setupScene() {
        // Setup body tracking configuration.
        let configuration = ARFaceTrackingConfiguration()
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            self.renderLoop()
        }.store(in: &subscriptions)
        
        /*
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
         */
         
        // Set session delegate.
        arView.session.delegate = self
    }

    /*
    // Process UI signals.
    func processUISignal(_ signal: ViewModel.UISignal) {
    }
     */
     
    // Setup method for non image anchor entities.
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)

        leftEyeEntity = makeBoxMarker(color: .red)
        originAnchor.addChild(leftEyeEntity)

        rightEyeEntity = makeBoxMarker(color: .blue)
        originAnchor.addChild(rightEyeEntity)
    }

    // Render loop.
    func renderLoop() {
    }

    // Called when anchors are updated.
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else { continue }
            
            let anchorTransform = faceAnchor.transform
            
            // Transform entities to left / right eyes.
            leftEyeEntity.transform.matrix  = anchorTransform * faceAnchor.leftEyeTransform
            rightEyeEntity.transform.matrix = anchorTransform * faceAnchor.rightEyeTransform

            // Get the blend shapes.
            let blendShapes = faceAnchor.blendShapes
            
            // Map blend value to yScale.
            if let eyeBlinkRight = blendShapes[.eyeBlinkRight] {
                let blendValue = Float(truncating: eyeBlinkRight)
                print("eyeBlinkRight:", blendValue)
                let yScale = 1 - mapRange(blendValue,
                                          low1: 0, high1: 0.7, low2: 0.1, high2: 0.8)
                rightEyeEntity.scale = [1, yScale, 1]
            }

            // Map blend value to yScale.
            if let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] {
                let blendValue = Float(truncating: eyeBlinkLeft)
                print("eyeBlinkLeft:", blendValue)
                let yScale = 1 - mapRange(blendValue,
                                          low1: 0, high1: 0.7, low2: 0.1, high2: 0.8)
                leftEyeEntity.scale = [1, yScale, 1]
            }
        }
    }

    // Map function. Similar to processing.
    func mapRange(_ value: Float, low1: Float, high1: Float, low2: Float, high2: Float) -> Float {
        return low2 + (high2 - low2) * (value - low1) / (high1 - low1);
    }

    // Helper method for making box.
    func makeBoxMarker(color: UIColor) -> Entity {
        let boxMesh   = MeshResource.generateBox(size: 0.05, cornerRadius: 0.002)
        var material  = PhysicallyBasedMaterial()
        material.baseColor.tint = color
        return ModelEntity(mesh: boxMesh, materials: [material])
    }
}

