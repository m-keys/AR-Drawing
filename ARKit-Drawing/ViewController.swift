import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var selectedNode: SCNNode?
    var placedNodes = [SCNNode]()
    var planeNodes = [SCNNode]()
    var lastObjectPlacedPoint: CGPoint?
    let touchDistanceThreshold: CGFloat = 40
    
    var showPlaneOverlay = false {
        didSet {
//            for node in planeNodes {
//                node.isHidden = !showPlaneOverlay
//            }
            planeNodes.forEach { node in
                node.isHidden = !showPlaneOverlay
            }
        }
    }

    @IBOutlet var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //sceneView.session.run(configuration)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func reloadConfiguration() {
        configuration.planeDetection = [.horizontal, .vertical]
        
        configuration.detectionImages = (objectMode == .image) ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil
        
        sceneView.session.run(configuration)
        
    }

    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let node = selectedNode, let touch = touches.first else { return }
        
        switch objectMode {
        case .freeform:
            addNodeInFront(node)
        case .plane:
            //break
            let touchPoint = touch.location(in: sceneView)
            addNode(node, toPlaneUsingPoint: touchPoint)
        case .image:
            break
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard objectMode == .plane,
            let node = selectedNode,
            let touch = touches.first,
            let lastTouchPoint = lastObjectPlacedPoint
            else { return }
        
        let newTouchPoint = touch.location(in: sceneView)
        
        let a = newTouchPoint.x - lastTouchPoint.x
        let b = newTouchPoint.y - lastTouchPoint.y
        let distance = sqrt(a * a + b * b)
        
        if touchDistanceThreshold < distance {
            addNode(node, toPlaneUsingPoint: newTouchPoint)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        lastObjectPlacedPoint = nil
    }
    
    func addNodeInFront(_ node: SCNNode) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        node.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        
        addNodeToSceneRoot(node)
    }
    
    func addNode(_ node: SCNNode, toPlaneUsingPoint point: CGPoint) {
        let result = sceneView.hitTest(point, types: [.existingPlaneUsingExtent])
        
        if let match = result.first {
            let position = match.worldTransform.columns.3
            node.position = SCNVector3(position.x, position.y, position.z)
            addNodeToSceneRoot(node)
            lastObjectPlacedPoint = point
        }
    }
    
    func addNodeToSceneRoot(_ node: SCNNode) {
        let cloneNode = node.clone()
        sceneView.scene.rootNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
    }
    
    func addNode(_ node: SCNNode, toImageUsingParentNode parentNode: SCNNode) {
        let cloneNode = node.clone()
        parentNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            nodeAdded(node, for: imageAnchor)
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            nodeAdded(node, for: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
        let planeNode = node.childNodes.first,
        let geometry = planeNode.geometry as? SCNPlane
            else { return }
        
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        geometry.width = CGFloat(planeAnchor.extent.x)
        geometry.height = CGFloat(planeAnchor.extent.z)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let floor = createFloor(planeAnchor: anchor)
        floor.isHidden = !showPlaneOverlay
        node.addChildNode(floor)
        planeNodes.append(floor)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        if let selectedNode = selectedNode {
            addNode(selectedNode, toImageUsingParentNode: node)
        }
    }
    
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let geometry = SCNPlane(width: width, height: height)
        let node = SCNNode(geometry: geometry)
        
        node.eulerAngles.x = -.pi / 2
        node.opacity = 0.25
        
        return node
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        showPlaneOverlay = !showPlaneOverlay
    }
    
    func undoLastObject() {
        if let lastNode = placedNodes.last {
            lastNode.removeFromParentNode()
            placedNodes.removeLast()
        }
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
}
