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

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var btnDraw: UIButton!
    
    var ndStartPost: SCNNode?
    var ndEndPost: SCNNode?
    let cameraPosition = SCNVector3(x: 0, y: 0, z: -0.1)
    
    let pointerImgView : UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.image = UIImage(named: "plus-8-64.png")
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        //sceneView.scene = scene
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        view.addSubview(pointerImgView)
        //pointerImgView.t
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointofView = sceneView.pointOfView else {return}
        let transform = pointofView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPostitionOfCamera = orientation + location
        DispatchQueue.main.sync {
            if self.btnDraw.isHighlighted {
                let scnDrawNode = SCNNode(geometry: SCNSphere(radius: 0.02))
                scnDrawNode.position = currentPostitionOfCamera
                //scnDrawNode.name = "PointerNode"
                self.sceneView.scene.rootNode.addChildNode(scnDrawNode)
                scnDrawNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            } else {
                let image = UIImage(named: "art.scnassets/plus-8-64.png")
                let pointerNode = SCNNode(geometry: SCNPlane(width: 0.01, height: 0.01))
                pointerNode.geometry?.firstMaterial?.diffuse.contents = image
                //let pointerNode = SCNNode(geometry: SCNSphere(radius: 0.01))
                pointerNode.position = currentPostitionOfCamera
                pointerNode.name = "PointerNode"
                self.sceneView.scene.rootNode.enumerateChildNodes({ (node, _) in
                    if node.name == "PointerNode" {
                        node.removeFromParentNode()
                    }
                })
                self.sceneView.scene.rootNode.addChildNode(pointerNode)
                //pointerNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        sceneView.debugOptions = [SCNDebugOptions.showFeaturePoints, SCNDebugOptions.showWorldOrigin]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func handleTapGesture(sender: UITapGestureRecognizer) {
        /*let tappedView = sender.view as! SCNView
        let touchLocation = sender.location(in: tappedView)
        let hitTest = tappedView.hitTest(touchLocation, options: nil)
        if !hitTest.isEmpty {
            let result = hitTest.first!
            let name = result.node.name
            let geomentry = result.node.geometry
            print("Tapped \(String(describing: name)) with the geometry \(String(describing: geomentry))")
        }*/
        
        if ndStartPost != nil && ndEndPost != nil {
            ndStartPost?.removeFromParentNode()
            ndEndPost?.removeFromParentNode()
            ndStartPost = nil
            ndEndPost = nil
        } else if ndStartPost != nil && ndEndPost == nil {
            let sphere = SCNNode(geometry: SCNSphere(radius: 0.001))
            sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            addChildNodeTo(node: sphere, toNode: sceneView.scene.rootNode, inView: sceneView, cameraRelativePost: cameraPosition)
            ndEndPost = sphere
        } else if ndStartPost == nil && ndEndPost == nil {
            let sphere = SCNNode(geometry: SCNSphere(radius: 0.001))
            sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            addChildNodeTo(node: sphere, toNode: sceneView.scene.rootNode, inView: sceneView, cameraRelativePost: cameraPosition)
            ndStartPost = sphere
        }
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
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
