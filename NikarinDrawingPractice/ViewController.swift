//
//  ViewController.swift
//  NikarinDrawingPractice
//
//  Created by Alpha on 25/10/18.
//  Copyright © 2018 SAG. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var btnDraw: UIButton!
    @IBOutlet weak var btnAnSave: UIButton!
    
    var ndStartPost: SCNNode?
    var ndEndPost: SCNNode?
    let cameraPosition = SCNVector3(x: 0, y: 0, z: -0.1)
    
    // MARK: - Persistence: Saving and Loading
    lazy var mapSaveURL: URL = {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("map.arexperience")
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
        print("mapSaveURL being called")
    }()
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        // Start the view's AR session.
        sceneView.session.delegate = self
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointofView = sceneView.pointOfView else {return}
        let transform = pointofView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPostitionOfCamera = orientation + location
        DispatchQueue.main.async {
            if self.btnDraw.isHighlighted {
                guard let currentFrame = self.sceneView.session.currentFrame else  { return }
                var translation = matrix_identity_float4x4
                translation.columns.3.z = -1
                let transform = currentFrame.camera.transform
                let rotation = matrix_float4x4(SCNMatrix4MakeRotation(Float.pi/2, 0, 0, 1))
                let anchorTransform = matrix_multiply(transform, matrix_multiply(translation, rotation))
                let anchor = ARAnchor(name: "AnjplsHelp", transform: anchorTransform)
                //let anchor = ARAnchor(transform: anchorTransform)
                self.sceneView.session.add(anchor: anchor)
            } else {
                let image = UIImage(named: "art.scnassets/plus-8-64.png")
                let pointerNode = SCNNode(geometry: SCNPlane(width: 0.01, height: 0.01))
                pointerNode.geometry?.firstMaterial?.diffuse.contents = image
                pointerNode.position = currentPostitionOfCamera
                pointerNode.name = "PointerNode"
                self.sceneView.scene.rootNode.enumerateChildNodes({ (node, _) in
                    if node.name == "PointerNode" {
                        node.removeFromParentNode()
                    }
                })
                self.sceneView.scene.rootNode.addChildNode(pointerNode)
            }
        }
    }
    
    /// - Tag: RestoreVirtualContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        if anchor.name != "AnjplsHelp" { return }
        let sphereNode = generateSphereNode()
        DispatchQueue.main.async {
            node.addChildNode(sphereNode)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Run the view's session
        sceneView.session.run(defaultConfiguration)
        sceneView.debugOptions = [SCNDebugOptions.showFeaturePoints]//, SCNDebugOptions.showWorldOrigin]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func addChildNodeTo(node: SCNNode, toNode: SCNNode, inView: ARSCNView, cameraRelativePost: SCNVector3) {
        guard let curFrame = inView.session.currentFrame else {return}
        let camera = curFrame.camera
        let transform = camera.transform
        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3.x = cameraRelativePost.x
        translationMatrix.columns.3.y = cameraRelativePost.y
        translationMatrix.columns.3.z = cameraRelativePost.z
        let modMatrix = simd_mul(transform, translationMatrix)
        node.simdTransform = modMatrix
        toNode.addChildNode(node)
    }

    // MARK: - ARSCNViewDelegate
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    @IBAction func clickSave(_ sender: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { self.showAlert(title: "Can't get current world map", message: error!.localizedDescription); return }
            
            // Add a snapshot image indicating where the map was captured.
            guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView)
                else { fatalError("Can't take snapshot") }
            map.anchors.append(snapshotAnchor)
            
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: self.mapSaveURL, options: [.atomic])
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }
        }
    }
    
    // Called opportunistically to verify that map data can be loaded from filesystem.
    var mapDataFromFile: Data? {
        return try? Data(contentsOf: mapSaveURL)
    }
    
    @IBAction func LoadSavedExperience(_ sender: UIButton) {
        /// - Tag: ReadWorldMap
        let worldMap: ARWorldMap = {
            guard let data = mapDataFromFile
                else { fatalError("Map data should already be verified to exist before Load button is enabled.") }
            do {
                guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
                    else { fatalError("No ARWorldMap in archive.") }
                return worldMap
            } catch {
                fatalError("Can't unarchive ARWorldMap from file data: \(error)")
            }
        }()
        print("going to load the anchor")
        // Remove the snapshot anchor from the world map since we do not need it in the scene.
        worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })
        
        let configuration = self.defaultConfiguration // this app's standard world tracking settings
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("Loaded anchor")
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    func generateSphereNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.01)
        //let sphere = SCNTorus(ringRadius: 0.01, pipeRadius: 0.001)
        let sphereNode = SCNNode()
        sphereNode.position.y += Float(sphere.radius)
        //sphereNode.position.y += Float(sphere.pipeRadius)
        //sphereNode.rotation = SCNVector4(1.0, 0, 0, Float(M_PI/4.0))
        sphereNode.geometry = sphere
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        return sphereNode
    }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
