//
//  ViewController.swift
//  ARmino
//
//  Created by Piotr Sirek on 16/01/2019.
//  Copyright © 2019 Piotr Sirek. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var removeAllButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    
    let dominoColors: [UIColor] = [.red, .blue, .green, .yellow, .orange, .cyan, .magenta, .purple]
    
    var detectedPlaces: [String: SCNNode] = [:]
    var dominoes: [SCNNode] = []
    
    var previousDominoPosition: SCNVector3?
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        removeAllButton.layer.cornerRadius = 12
        startButton.layer.cornerRadius = 12
        
        sceneView.delegate = self
        let scene = SCNScene()
        
        sceneView.scene = scene
        sceneView.scene.physicsWorld.timeStep = 1/200
        
        let panGeture = UIPanGestureRecognizer(target: self, action: #selector(screenPanned))
        sceneView.addGestureRecognizer(panGeture)
        
        addLight()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func distanceBetween(point1: SCNVector3, addPoint2 point2: SCNVector3) -> Float {
        return hypotf(Float(point1.x - point2.x), Float(point1.z - point2.z))
    }
    
    @objc func screenPanned(gesture: UIPanGestureRecognizer) {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        let location = gesture.location(in: sceneView)
        guard let hitTestResult = sceneView.hitTest(location, types: .existingPlane).first else { return }
        
        guard let previousPosition = previousDominoPosition else {
            self.previousDominoPosition = SCNVector3Make(hitTestResult.worldTransform.columns.3.x, hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z)
            return
        }
        
        let currentPosition = SCNVector3Make(hitTestResult.worldTransform.columns.3.x, hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z)
        let minimumDistanceBetweenDominoes: Float = 0.03
        let distance = distanceBetween(point1: previousPosition, addPoint2: currentPosition)
        if distance >= minimumDistanceBetweenDominoes {
            
            let dominoGeometry = SCNBox(width: 0.007, height: 0.06, length: 0.03, chamferRadius: 0.0)
            dominoGeometry.firstMaterial?.diffuse.contents = dominoColors.randomElement()
            let dominoNode = SCNNode(geometry: dominoGeometry)
            dominoNode.position = SCNVector3Make(currentPosition.x, currentPosition.y + 0.03, currentPosition.z)
            
            var currentAngle: Float = pointPairToBearingDegrees(startingPoint: CGPoint(x: CGFloat(currentPosition.x), y: CGFloat(currentPosition.z)), secondPoint: CGPoint(x: CGFloat(previousPosition.x), y: CGFloat(previousPosition.z)))
            
            currentAngle *= .pi / 180
            dominoNode.rotation = SCNVector4Make(0, 1, 0, -currentAngle)
            
            dominoNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            
            dominoNode.physicsBody?.mass = 2.0
            dominoNode.physicsBody?.friction = 0.8
            
            sceneView.scene.rootNode.addChildNode(dominoNode)
            
            dominoes.append(dominoNode)
            
            self.previousDominoPosition = currentPosition
        }
    }
    
    func pointPairToBearingDegrees(startingPoint: CGPoint, secondPoint endingPoint: CGPoint) -> Float {
        let originPoint: CGPoint = CGPoint(x: startingPoint.x - endingPoint.x, y: startingPoint.y - endingPoint.y)
        let bearingRadians = atan2f(Float(originPoint.y), Float(originPoint.x))
        let bearingDegrees = bearingRadians * (100 / Float.pi)
        
        return bearingDegrees
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
      
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.y))
        plane.firstMaterial?.colorBufferWriteMask = .init(rawValue: 0)
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        planeNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 2.0)
        
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
        
        node.addChildNode(planeNode)
        
        detectedPlaces[planeAnchor.identifier.uuidString] = planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return  }
        
        guard let planeNode = detectedPlaces[planeAnchor.identifier.uuidString] else { return }
        let planeGeometry = planeNode.geometry as! SCNPlane
        planeGeometry.width = CGFloat(planeAnchor.center.x)
        planeGeometry.height = CGFloat(planeAnchor.center.y)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        planeNode.physicsBody?.physicsShape = SCNPhysicsShape(geometry: box, options: nil)
    }

    @IBAction func removeAllDominoesButtonPressed(_ sender: Any) {
        for domino in dominoes {
            domino.removeFromParentNode()
            self.previousDominoPosition = nil
        }
        
        dominoes = []
    }
    
    @IBAction func startButtonPressed(_ sender: Any) {
        guard let firstDomino = dominoes.first else { return }
        
        let power: Float = 0.7
        firstDomino.physicsBody?.applyForce(SCNVector3Make(firstDomino.worldRight.x * power, firstDomino.worldRight.y * power, firstDomino.worldRight.z * power), asImpulse: true)
    }
    
    func addLight() {
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 500
        
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        
        directionalLight.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 3)
        sceneView.scene.rootNode.addChildNode(directionalLightNode)
        
        let ambientLight = SCNLight()
        ambientLight.intensity = 50
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        sceneView.scene.rootNode.addChildNode(ambientLightNode)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {

    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        
    }
}
