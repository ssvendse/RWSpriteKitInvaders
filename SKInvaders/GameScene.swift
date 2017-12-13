/**
 * Copyright (c) 2016 Razeware LLC
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
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
  
  
    var contentCreated = false
    
    var invaderMovementDirection: InvaderMovementDirection = .right
    var timeOfLastMove: CFTimeInterval = 0.0
    var timePerMove: CFTimeInterval = 1.0
    
    let motionManager = CMMotionManager()
    
    var tapQueue = [Int]()
    
    let kShipFiredBulletName = "shipFiredBullet"
    let kInvaderFiredBulletName = "invaderFiredBullet"
    let kBulletSize = CGSize(width: 4, height: 8)
    
    let kInvaderCategory: UInt32 = 0x1 << 0
    let kShipFiredBulletCategory: UInt32 = 0x1 << 1
    let kShipCategory: UInt32 = 0x1 << 2
    let kSceneEdgeCategory: UInt32 = 0x1 << 3
    let kInvaderFiredBulletCategory: UInt32 = 0x1 << 4
    
    var contactQueue = [SKPhysicsContact]()
    
    var score: Int = 0
    var shipHealth: Float = 1.0
    
    let kMinInvaderBottomHeight: Float = 32.0
    var gameEnding: Bool = false
    
    enum InvaderMovementDirection {
        case right
        case left
        case downThenRight
        case downThenLeft
        case none
    }
    
    enum InvaderType {
        case a
        case b
        case c
        
        static var size: CGSize {
            return CGSize(width: 24, height: 16)
        }
    
        static var name: String {
            return "invader"
        }
    }
    
    enum BulletType {
        case shipFired
        case invaderFired
    }
    
    let kInvaderGridSpacing = CGSize(width: 12, height: 12)
    let kInvaderRowCount = 6
    let kInvaderColCount = 6
    let kShipSize = CGSize(width: 30, height: 16)
    let kShipName = "ship"
    let kScoreHudName = "scoreHud"
    let kHealthHudName = "healthHud"
  
  // Object Lifecycle Management
  
  // Scene Setup and Content Creation
    override func didMove(to view: SKView) {
        
        if (!self.contentCreated) {
            self.createContent()
            self.contentCreated = true
            
            motionManager.startAccelerometerUpdates()
        }
        
        physicsWorld.contactDelegate = self
    }
    
    func createContent() {
        
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        
        physicsBody!.categoryBitMask = kSceneEdgeCategory
        
        setupInvaders()
        setupShip()
        setupHud()
        
        // black space color
        self.backgroundColor = SKColor.black
    }
    
    func loadInvaderTextures(ofType invaderType: InvaderType) -> [SKTexture] {
        var prefix: String
        switch invaderType {
        case .a:
            prefix = "InvaderA"
        case .b:
            prefix = "InvaderB"
        case .c:
            prefix = "InvaderC"
        }
        
        return [SKTexture(imageNamed: String(format: "%@_00.png", prefix)),
                SKTexture(imageNamed: String(format: "%@_01.png", prefix))]
    }
    
    func makeInvader(ofType invaderType: InvaderType) -> SKNode {
        let invaderTextures = loadInvaderTextures(ofType: invaderType)
        
        let invader = SKSpriteNode(texture: invaderTextures[0])
        invader.name = InvaderType.name
        
        invader.run(SKAction.repeatForever(SKAction.animate(with: invaderTextures, timePerFrame: timePerMove)))
        
        invader.physicsBody = SKPhysicsBody(rectangleOf: invader.frame.size)
        invader.physicsBody?.isDynamic = false
        invader.physicsBody?.categoryBitMask = kInvaderCategory
        invader.physicsBody?.contactTestBitMask = 0x0
        invader.physicsBody?.collisionBitMask = 0x0
        
        return invader
    }
  
    func setupInvaders() {
        let baseOrigin = CGPoint(x: size.width / 3, y: size.height / 2)
        
        for row in 0..<kInvaderRowCount {
            var invaderType: InvaderType
            
            if row % 3 == 0 {
                invaderType = .a
            } else if row % 3 == 1 {
                invaderType = .b
            } else {
                invaderType = .c
            }
            
            let invaderPositionY = CGFloat(row) * (InvaderType.size.height * 2) + baseOrigin.y
            
            var invaderPosition = CGPoint(x: baseOrigin.x, y: invaderPositionY)
            
            for _ in 1..<kInvaderColCount {
                let invader = makeInvader(ofType: invaderType)
                invader.position = invaderPosition
                
                addChild(invader)
                
                invaderPosition = CGPoint(
                    x: invaderPosition.x + InvaderType.size.width + kInvaderGridSpacing.width,
                    y: invaderPositionY)
            }
        }
    }
    
    func setupShip() {
        let ship = makeShip()
        
        ship.position = CGPoint(x: size.width / 2.0, y: kShipSize.height / 2.0)
        addChild(ship)
    }
    
    func makeShip() -> SKNode {
        let ship = SKSpriteNode(imageNamed: "Ship.png")
        ship.name = kShipName
        
        ship.physicsBody = SKPhysicsBody(rectangleOf: ship.frame.size)
        ship.physicsBody?.isDynamic = true
        ship.physicsBody?.affectedByGravity = false
        ship.physicsBody?.mass = 0.2
        
        ship.physicsBody?.categoryBitMask = kShipCategory
        ship.physicsBody?.contactTestBitMask = 0x0
        ship.physicsBody?.collisionBitMask = kSceneEdgeCategory
        
        return ship
    }
    
    func setupHud() {
        let scoreLabel = SKLabelNode(fontNamed: "Courier")
        scoreLabel.name = kScoreHudName
        scoreLabel.fontSize = 25
        
        scoreLabel.fontColor = SKColor.green
        scoreLabel.text = String(format: "Score: %04u", 0)
        
        scoreLabel.position = CGPoint(x: frame.size.width / 2, y: size.height - (40 + scoreLabel.frame.size.height/2))
        addChild(scoreLabel)
        
        let healthLabel = SKLabelNode(fontNamed: "Courier")
        healthLabel.name = kHealthHudName
        healthLabel.fontSize = 25
        
        healthLabel.fontColor = SKColor.red
        healthLabel.text = String(format: "Health: %.1f%%", shipHealth * 100.0)
        
        healthLabel.position = CGPoint(x: frame.size.width / 2, y: size.height - (80 + healthLabel.frame.size.height/2))
        addChild(healthLabel)
    }
    
    func adjustScore(by points: Int) {
        score += points
        
        if let score = childNode(withName: kScoreHudName) as? SKLabelNode {
            score.text = String(format: "Score: %04u", self.score)
        }
    }
    
    func adjustShipHealth(by healthAdjustment: Float) {
        shipHealth = max(shipHealth + healthAdjustment, 0)
        
        if let health = childNode(withName: kHealthHudName) as? SKLabelNode {
            health.text = String(format: "Health: %.1f%%", self.shipHealth * 100)
        }
    }
    
    func makeBullet(ofType bulletType: BulletType) -> SKNode {
        var bullet: SKNode
        
        switch bulletType {
        case .shipFired:
            bullet = SKSpriteNode(color: SKColor.green, size: kBulletSize)
            bullet.name = kShipFiredBulletName
            
            bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.frame.size)
            bullet.physicsBody?.isDynamic = true
            bullet.physicsBody?.affectedByGravity = false
            bullet.physicsBody?.categoryBitMask = kShipFiredBulletCategory
            bullet.physicsBody?.contactTestBitMask = kInvaderCategory
            bullet.physicsBody?.collisionBitMask = 0x0
        case .invaderFired:
            bullet = SKSpriteNode(color: SKColor.magenta, size: kBulletSize)
            bullet.name = kInvaderFiredBulletName
            
            bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.frame.size)
            bullet.physicsBody?.isDynamic = true
            bullet.physicsBody?.affectedByGravity = false
            bullet.physicsBody?.categoryBitMask = kInvaderFiredBulletCategory
            bullet.physicsBody?.contactTestBitMask = kShipCategory
            bullet.physicsBody?.collisionBitMask = 0x0
            break
        }
        
        return bullet
    }
    
  // Scene Update
  
    func moveInvaders(forUpdate currentTime: CFTimeInterval) {
        if (currentTime - timeOfLastMove < timePerMove) {
            return
        }
        
        determineInvaderMovementDirection()
        
        enumerateChildNodes(withName: InvaderType.name) { node, stop in
            switch self.invaderMovementDirection {
            case .right:
                node.position = CGPoint(x: node.position.x + 10, y: node.position.y)
            case .left:
                node.position = CGPoint(x: node.position.x - 10, y: node.position.y)
                
            //not working currently
            case .downThenLeft, .downThenRight:
                node.position = CGPoint(x: node.position.x, y: node.position.y - 10)
            case .none:
                break
            }
            
            self.timeOfLastMove = currentTime
        }
    }
    
    func adjustInvaderMovement(to timePerMove: CFTimeInterval) {
        if self.timePerMove <= 0 {
            return
        }
        
        let ratio: CGFloat = CGFloat(self.timePerMove / timePerMove)
        self.timePerMove = timePerMove
        
        enumerateChildNodes(withName: InvaderType.name) { node, stop in
            node.speed = node.speed * ratio
        }
    }
    
    func processUserMotion(forUpdate currentTime: CFTimeInterval) {
        if let ship = childNode(withName: kShipName) as? SKSpriteNode {
            if let data = motionManager.accelerometerData {
                if fabs(data.acceleration.x) > 0.2 {
                    ship.physicsBody!.applyForce(CGVector(dx: 40 * CGFloat(data.acceleration.x), dy: 0))
                }
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if isGameOver(){
            endGame()
        }
        
        processContacts(forUpdate: currentTime)
        processUserTaps(forUpdate: currentTime)
        processUserMotion(forUpdate: currentTime)
        moveInvaders(forUpdate: currentTime)
        fireInvaderBullets(forUpdate: currentTime)
    }
    
    func fireInvaderBullets(forUpdate currentTime: CFTimeInterval) {
        let existingBullet = childNode(withName: kInvaderFiredBulletName)
        
        if existingBullet == nil {
            var allInvaders = [SKNode]()
            
            enumerateChildNodes(withName: InvaderType.name) { node, stop in
                allInvaders.append(node)
            }
            
            if allInvaders.count > 0 {
                let allInvadersIndex = Int(arc4random_uniform(UInt32(allInvaders.count)))
                
                let invader = allInvaders[allInvadersIndex]
                
                let bullet = makeBullet(ofType: .invaderFired)
                
                bullet.position = CGPoint(
                    x: invader.position.x,
                    y: invader.position.y - invader.frame.size.height / 2 + bullet.frame.size.height / 2
                )
                
                let bulletDestination = CGPoint(x: invader.position.x, y: -(bullet.frame.size.height / 2))
                
                fireBullet(bullet: bullet, toDestination: bulletDestination, withDuration: 2.0, andSoundFileName: "InvaderBullet.wav")
            }
        }
    }
  
  // Scene Update Helpers
    
    func processUserTaps(forUpdate currentTime: CFTimeInterval) {
        for tapCount in tapQueue {
            if tapCount == 1 {
                fireShipBullets()
            }
            
            tapQueue.remove(at: 0)
        }
    }
    
    func processContacts(forUpdate currentTime: CFTimeInterval) {
        for contact in contactQueue {
            handle(contact)
            
            if let index = contactQueue.index(of: contact) {
                contactQueue.remove(at: index)
            }
        }
    }
  
  // Invader Movement Helpers
  
    func determineInvaderMovementDirection() {
        
        var proposedMovementDirection: InvaderMovementDirection = invaderMovementDirection
        
        enumerateChildNodes(withName: InvaderType.name) { node, stop in
            
            switch self.invaderMovementDirection {
            case .right:
                if (node.frame.maxX >= node.scene!.size.width - 1.0) {
                    proposedMovementDirection = .downThenLeft

                    stop.pointee = true
                }
            case .left:
                if (node.frame.minX <= 1.0) {
                    proposedMovementDirection = .downThenRight

                    stop.pointee = true
                }
            case .downThenLeft:
                proposedMovementDirection = .left
                
                stop.pointee = true
            case .downThenRight:
                proposedMovementDirection = .right
                
                stop.pointee = true
            default:
                break
            }
            
        }
        
        if (proposedMovementDirection != invaderMovementDirection) {
            invaderMovementDirection = proposedMovementDirection
        }
    }
  // Bullet Helpers
    
    func fireBullet(bullet: SKNode, toDestination destination: CGPoint, withDuration duration: CFTimeInterval, andSoundFileName soundName: String) {
        let bulletAction = SKAction.sequence([
            SKAction.move(to: destination, duration: duration),
            SKAction.wait(forDuration: 3.0 / 60.0),
            SKAction.removeFromParent()
            ])
        
        let soundAction = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        bullet.run(SKAction.group([bulletAction, soundAction]))
        
        addChild(bullet)
    }
    
    func fireShipBullets() {
        let existingBullet = childNode(withName: kShipFiredBulletName)
        
        if existingBullet == nil {
            if let ship = childNode(withName: kShipName) {
                let bullet = makeBullet(ofType: .shipFired)
                
                bullet.position = CGPoint(
                    x: ship.position.x,
                    y: ship.position.y + ship.frame.size.height - bullet.frame.size.height / 2
                )
                
                let bulletDestination = CGPoint(
                    x: ship.position.x,
                    y: frame.size.height + bullet.frame.size.height / 2
                )
                
                fireBullet(bullet: bullet, toDestination: bulletDestination, withDuration: 1.0, andSoundFileName: "ShipBullet.wav")
            }
        }
    }
  
  // User Tap Helpers
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            if (touch.tapCount == 1) {
                tapQueue.append(1)
            }
        }
    }
  
  // HUD Helpers
  
  // Physics Contact Helpers
    
    func didBegin(_ contact: SKPhysicsContact) {
        contactQueue.append(contact)
    }
    
    func handle(_ contact: SKPhysicsContact) {
        if contact.bodyA.node?.parent == nil || contact.bodyB.node?.parent == nil {
            return
        }
        
        let nodeNames = [contact.bodyA.node?.name, contact.bodyB.node?.name]
        
        //kshipname, kinvaderfiredbulletname
        if nodeNames.contains(where: {$0 == kShipName}) && nodeNames.contains(where: {$0 == kInvaderFiredBulletName}) {
            run(SKAction.playSoundFileNamed("ShipHit.wav", waitForCompletion: false))
            
            adjustShipHealth(by: -0.334)
            
            if shipHealth <= 0.0 {
                contact.bodyA.node?.removeFromParent()
                contact.bodyB.node?.removeFromParent()
            } else {
                if let ship = childNode(withName: kShipName) {
                    ship.alpha = CGFloat(shipHealth)
                    
                    if contact.bodyA.node == ship {
                        contact.bodyB.node?.removeFromParent()
                    } else {
                        contact.bodyA.node?.removeFromParent()
                    }
                }
            }
            
        } else if nodeNames.contains(where: {$0 == InvaderType.name}) && nodeNames.contains(where: {$0 == kShipFiredBulletName}) {
            run(SKAction.playSoundFileNamed("InvaderHit.wav", waitForCompletion: false))
            
            contact.bodyA.node?.removeFromParent()
            contact.bodyB.node?.removeFromParent()
            
            adjustScore(by: 100)
        }
        
    }
    
    
  
  // Game End Helpers
    
    func isGameOver() -> Bool {
        let invader = childNode(withName: InvaderType.name)
        
        var invaderTooLow = false
        
        enumerateChildNodes(withName: InvaderType.name) { node, stop in
            if (Float(node.frame.minY) <= self.kMinInvaderBottomHeight) {
                invaderTooLow = true
                stop.pointee = true
            }
        }
        
        let ship = childNode(withName: kShipName)
        
        return invader == nil || invaderTooLow || ship == nil
    }
    
    func endGame() {
        if !gameEnding {
            gameEnding = true
            
            motionManager.stopAccelerometerUpdates()
            
            let gameOverScene: GameOverScene = GameOverScene(size:size)
            
            view?.presentScene(gameOverScene, transition: SKTransition.doorsOpenHorizontal(withDuration: 1.0))
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
  
}
