//
//  VHSTapeModel.swift
//  video interaction
//
//  Created by Michael Lee on 11/22/25.
//

import SceneKit

class VHSTapeModel {
    static func createTape(label: String? = nil, isSelected: Bool = false) -> SCNNode {
        let tapeNode = SCNNode()

        // VHS tape dimensions (approximate, in SceneKit units)
        let width: CGFloat = 1.87
        let height: CGFloat = 1.03
        let depth: CGFloat = 0.29

        // --- 1. Main Body (Matte Black ABS) ---
        let bodyGeometry = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.02) // Rounded edges
        let bodyMaterial = SCNMaterial()
        bodyMaterial.lightingModel = .physicallyBased
        bodyMaterial.diffuse.contents = isSelected
            ? UIColor(red: 0.96, green: 0.42, blue: 0.08, alpha: 1.0)
            : UIColor(white: 0.1, alpha: 1.0)
        bodyMaterial.emission.contents = isSelected
            ? UIColor(red: 0.08, green: 0.025, blue: 0.0, alpha: 1.0)
            : UIColor.black
        bodyMaterial.roughness.contents = isSelected ? 0.44 : 0.6
        bodyMaterial.metalness.contents = 0.1
        bodyGeometry.materials = [bodyMaterial]

        let bodyNode = SCNNode(geometry: bodyGeometry)
        tapeNode.addChildNode(bodyNode)

        // --- 3. Reels (Visible through window) ---
        let reelY = height * 0.15
        let reelZ = depth/2 - 0.08 // Inside the tape
        let reelSpacing = width * 0.28

        let leftReel = createDetailedReel()
        leftReel.position = SCNVector3(-reelSpacing, reelY, reelZ)
        tapeNode.addChildNode(leftReel)

        let rightReel = createDetailedReel()
        rightReel.position = SCNVector3(reelSpacing, reelY, reelZ)
        tapeNode.addChildNode(rightReel)

        // Tape Strip (Dark brown, between reels)
        let tapeStripGeometry = SCNPlane(width: width * 0.55, height: height * 0.18)
        let tapeStripMaterial = SCNMaterial()
        tapeStripMaterial.diffuse.contents = UIColor(red: 0.1, green: 0.05, blue: 0.0, alpha: 1.0) // Dark brown
        tapeStripMaterial.roughness.contents = 0.3
        tapeStripGeometry.materials = [tapeStripMaterial]

        let tapeStripNode = SCNNode(geometry: tapeStripGeometry)
        tapeStripNode.position = SCNVector3(0, reelY, reelZ - 0.01) // Behind reels slightly
        tapeNode.addChildNode(tapeStripNode)


        // --- 5. Flip-up Flap (Top Edge) ---
        let flapHeight = height * 0.15
        let flapGeometry = SCNBox(width: width * 0.98, height: flapHeight, length: depth * 1.05, chamferRadius: 0.01)
        let flapMaterial = SCNMaterial()
        flapMaterial.diffuse.contents = isSelected
            ? UIColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1.0)
            : UIColor(white: 0.15, alpha: 1.0)
        flapMaterial.emission.contents = isSelected
            ? UIColor(red: 0.09, green: 0.035, blue: 0.0, alpha: 1.0)
            : UIColor.black
        flapMaterial.roughness.contents = 0.3
        flapGeometry.materials = [flapMaterial]

        let flapNode = SCNNode(geometry: flapGeometry)
        flapNode.position = SCNVector3(0, height/2 - flapHeight/2, 0)
        tapeNode.addChildNode(flapNode)

        if let label {
            tapeNode.addChildNode(createTopLabel(label, width: width, height: height))
        }

        return tapeNode
    }

    private static func createTopLabel(_ label: String, width: CGFloat, height: CGFloat) -> SCNNode {
        let labelNode = SCNNode()

        let plateGeometry = SCNPlane(width: width * 0.86, height: height * 0.2)
        let plateMaterial = SCNMaterial()
        plateMaterial.diffuse.contents = UIColor(white: 0.02, alpha: 0.72)
        plateMaterial.emission.contents = UIColor(white: 0.01, alpha: 0.35)
        plateMaterial.isDoubleSided = true
        plateGeometry.materials = [plateMaterial]

        let plateNode = SCNNode(geometry: plateGeometry)
        plateNode.eulerAngles.x = -Float.pi / 2
        plateNode.position = SCNVector3(0, Float(height / 2 + 0.03), 0)
        labelNode.addChildNode(plateNode)

        let textGeometry = SCNText(string: label, extrusionDepth: 0.008)
        textGeometry.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        textGeometry.flatness = 0.02
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = UIColor.white
        textMaterial.emission.contents = UIColor(white: 0.34, alpha: 1.0)
        textGeometry.materials = [textMaterial]

        let textNode = SCNNode(geometry: textGeometry)
        let (minBounds, maxBounds) = textGeometry.boundingBox
        let centerX = (minBounds.x + maxBounds.x) / 2
        let centerY = (minBounds.y + maxBounds.y) / 2

        textNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)
        textNode.scale = SCNVector3(0.016, 0.016, 0.016)
        textNode.eulerAngles.x = -Float.pi / 2
        textNode.position = SCNVector3(0, Float(height / 2 + 0.05), 0)

        // Keep longer names from visually spilling past the top face.
        let maxLabelWidth = Float(width * 0.78)
        let measuredWidth = (maxBounds.x - minBounds.x) * textNode.scale.x
        if measuredWidth > maxLabelWidth {
            let fittedScale = maxLabelWidth / measuredWidth
            textNode.scale = SCNVector3(
                textNode.scale.x * fittedScale,
                textNode.scale.y * fittedScale,
                textNode.scale.z
            )
        }

        labelNode.addChildNode(textNode)

        return labelNode
    }

    private static func createDetailedReel() -> SCNNode {
        let reelNode = SCNNode()

        // Hub (White plastic)
        let hubRadius: CGFloat = 0.22
        let hubGeometry = SCNCylinder(radius: hubRadius, height: 0.02)
        let hubMaterial = SCNMaterial()
        hubMaterial.diffuse.contents = UIColor(white: 0.9, alpha: 1.0) // Off-white
        hubMaterial.roughness.contents = 0.5
        hubGeometry.materials = [hubMaterial]

        let hubNode = SCNNode(geometry: hubGeometry)
        hubNode.eulerAngles.x = Float.pi / 2
        reelNode.addChildNode(hubNode)

        // Spokes (Visualized as a texture or simple geometry pattern)
        // For 3D geometry spokes:
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let spoke = SCNBox(width: 0.04, height: hubRadius * 0.8, length: 0.025, chamferRadius: 0.0)
            spoke.firstMaterial?.diffuse.contents = UIColor(white: 0.8, alpha: 1.0) // Slightly darker
            let spokeNode = SCNNode(geometry: spoke)
            spokeNode.position = SCNVector3(0, 0, 0.01)
            spokeNode.eulerAngles.z = Float(angle)
            reelNode.addChildNode(spokeNode)
        }

        return reelNode
    }
}
