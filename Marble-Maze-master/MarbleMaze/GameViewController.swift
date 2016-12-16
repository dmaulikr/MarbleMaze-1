//
//  GameViewController.swift
//  MarbleMaze
//
//  Created by Bill Yu on 5/24/16.
//  Copyright (c) 2016 Bill Yu. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController {
    
    var scnView: SCNView!
    var scnScene: SCNScene!
    
    let CollisionCategoryBall = 1
    let CollisionCategoryStone = 2
    let CollisionCategoryPillar = 4
    let CollisionCategoryCrate = 8
    let CollisionCategoryPearl = 16
    
    var ballNode: SCNNode!
    var cameraNode: SCNNode!
    var cameraFollowNode: SCNNode!
    var lightFollowNode: SCNNode!
    
    var game = GameHelper.sharedInstance
    var motion = CoreMotionHelper();
    var motionForce = SCNVector3(x: 0, y: 0, z: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupNodes()
        setupSounds()
        resetGame()
    }
    
    func setupScene() {
        scnView = self.view as! SCNView
        scnView.delegate = self
        scnScene = SCNScene(named: "art.scnassets/game.scn")
        scnView.scene = scnScene
        scnScene.physicsWorld.contactDelegate = self
    }
    
    func setupNodes() {
        ballNode = scnScene.rootNode.childNodeWithName("ball", recursively: true)!
        ballNode.physicsBody?.contactTestBitMask = CollisionCategoryPillar | CollisionCategoryCrate | CollisionCategoryPearl
        cameraNode = scnScene.rootNode.childNodeWithName("camera", recursively: true)!
        let constraint = SCNLookAtConstraint(target: ballNode)
        cameraNode.constraints = [constraint]
        constraint.gimbalLockEnabled = true
        
        cameraFollowNode = scnScene.rootNode.childNodeWithName("follow_camera", recursively: true)!
        cameraNode.addChildNode(game.hudNode);
        lightFollowNode = scnScene.rootNode.childNodeWithName("follow_light", recursively: true)!
    }
    
    func setupSounds() {
        game.loadSound("GameOver", fileNamed: "GameOver.wav")
        game.loadSound("Powerup", fileNamed: "Powerup.wav")
        game.loadSound("Reset", fileNamed: "Reset.wav")
        game.loadSound("Bump", fileNamed: "Bump.wav")
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // 1
    func playGame() {
        game.state = GameStateType.Playing
        cameraFollowNode.eulerAngles.y = 0
        cameraFollowNode.position = SCNVector3Zero
        replenishLife()
    }
    // 2
    func resetGame() {
        game.state = GameStateType.TapToPlay
        game.playSound(ballNode, name: "Reset")
        ballNode.physicsBody!.velocity = SCNVector3Zero
        ballNode.position = SCNVector3(x:0, y:10, z:0)
        cameraFollowNode.position = ballNode.position
        lightFollowNode.position = ballNode.position
        scnView.playing = true
        game.reset()
    }
    // 3
    func testForGameOver() {
        if ballNode.presentationNode.position.y < -5 {
            game.state = GameStateType.GameOver
            game.playSound(ballNode, name: "GameOver")
            ballNode.runAction(SCNAction.waitForDurationThenRunBlock(3)
            { (node:SCNNode!) -> Void in
                self.resetGame()
                })
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event:
        UIEvent?) {
        if game.state == GameStateType.TapToPlay {
            playGame()
        }
    }
    
    func updateMotionControl() {
        if game.state == GameStateType.Playing {
            motion.getAccelerometerData(0.1) { (x,y,z) in
                self.motionForce = SCNVector3(x: Float(x) * 0.05, y:0, z: Float(y + 0.8) * -0.05)
            }
            ballNode.physicsBody!.velocity += motionForce
        }
    }
    
    func replenishLife() {
        // 1
        let material = ballNode.geometry!.firstMaterial!
        // 2
        SCNTransaction.begin()
        SCNTransaction.setAnimationDuration(1.0)
        // 3
        material.emission.intensity = 1.0
        // 4
        SCNTransaction.commit()
        // 5
        game.score += 1
        game.playSound(ballNode, name: "Powerup")
    }
    
    func diminishLife() {
        // 1
        let material = ballNode.geometry!.firstMaterial!
        // 2
        if material.emission.intensity > 0 {
            material.emission.intensity -= 0.001
        } else {
            resetGame()
        }
    }
    
    func updateCameraAndLights() {
        // 1
        let lerpX = (ballNode.presentationNode.position.x -
            cameraFollowNode.position.x) * 0.01
        let lerpY = (ballNode.presentationNode.position.y -
            cameraFollowNode.position.y) * 0.01
        let lerpZ = (ballNode.presentationNode.position.z -
            cameraFollowNode.position.z) * 0.01
        cameraFollowNode.position.x += lerpX
        cameraFollowNode.position.y += lerpY
        cameraFollowNode.position.z += lerpZ
        // 2
        lightFollowNode.position = cameraFollowNode.position
        // 3
        if game.state == GameStateType.TapToPlay {
            cameraFollowNode.eulerAngles.y += 0.005
        }
    }
    
    func updateHUD() {
        switch game.state {
        case .Playing:
            game.updateHUD()
        case .GameOver:
            game.updateHUD("-GAME OVER-")
        case .TapToPlay:
            game.updateHUD("-TAP TO PLAY-")
        }
    }
}

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(renderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        updateHUD()
        updateMotionControl()
        updateCameraAndLights()
        if game.state == GameStateType.Playing {
            testForGameOver()
            diminishLife()
        }
    }
}

extension GameViewController : SCNPhysicsContactDelegate {
    func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact:
        SCNPhysicsContact) {
        // 1
        var contactNode:SCNNode!
        if contact.nodeA.name == "ball" {
            contactNode = contact.nodeB
        } else {
            contactNode = contact.nodeA
        }
        // 2
        if contactNode.physicsBody?.categoryBitMask == CollisionCategoryPearl {
            contactNode.hidden = true
            contactNode.runAction(SCNAction.waitForDurationThenRunBlock(30) {
                (node:SCNNode!) -> Void in
                node.hidden = false
            })
            replenishLife()
        }
        if contactNode.physicsBody?.categoryBitMask == CollisionCategoryPillar
            || contactNode.physicsBody?.categoryBitMask == CollisionCategoryCrate {
            game.playSound(ballNode, name: "Bump")
        }
    }
}