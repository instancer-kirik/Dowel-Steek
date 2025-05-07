module bridge.scene3d;

import dlangui;
import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;
import dlangui.core.types;
import std.json;
import std.math;
import std.conv;

// Basic 3D object types
enum ObjectType {
    Cube,
    Sphere,
    Cylinder,
    Grid
}

// Scene object with transform
class SceneObject {
    vec3 position;
    vec3 rotation;
    vec3 scale;
    ObjectType type;
    string id;
    
    this(string id, ObjectType type) {
        this.id = id;
        this.type = type;
        position = vec3(0, 0, 0);
        rotation = vec3(0, 0, 0);
        scale = vec3(1, 1, 1);
    }
    
    void render(GLDrawBuf buf) {
        // Use DlangUI's drawing methods
        buf.save();
        
        // Apply transformations using DlangUI's methods
        buf.translate(position.x, position.y, position.z);
        buf.rotateX(rotation.x * 180.0f / PI);
        buf.rotateY(rotation.y * 180.0f / PI);
        buf.rotateZ(rotation.z * 180.0f / PI);
        
        // Draw based on type
        final switch(type) {
            case ObjectType.Cube:
                drawCube(buf);
                break;
            case ObjectType.Sphere:
                drawSphere(buf);
                break;
            case ObjectType.Cylinder:
                drawCylinder(buf);
                break;
            case ObjectType.Grid:
                drawGrid(buf);
                break;
        }
        
        buf.restore();
    }
    
    private void drawCube(GLDrawBuf buf) {
        // Draw cube wireframe using DlangUI's line drawing
        buf.setColor(0xFFFFFF);
        
        // Front face
        buf.drawLine(Point(-1, -1), Point(1, -1));
        buf.drawLine(Point(1, -1), Point(1, 1));
        buf.drawLine(Point(1, 1), Point(-1, 1));
        buf.drawLine(Point(-1, 1), Point(-1, -1));
        
        // Back face
        buf.drawLine(Point(-1, -1, -1), Point(1, -1, -1));
        buf.drawLine(Point(1, -1, -1), Point(1, 1, -1));
        buf.drawLine(Point(1, 1, -1), Point(-1, 1, -1));
        buf.drawLine(Point(-1, 1, -1), Point(-1, -1, -1));
        
        // Connecting lines
        buf.drawLine(Point(-1, -1, -1), Point(-1, -1, 1));
        buf.drawLine(Point(1, -1, -1), Point(1, -1, 1));
        buf.drawLine(Point(1, 1, -1), Point(1, 1, 1));
        buf.drawLine(Point(-1, 1, -1), Point(-1, 1, 1));
    }
    
    private void drawSphere(GLDrawBuf buf) {
        // Draw sphere approximation using circles
        buf.setColor(0xFFFFFF);
        
        // Draw three main circles
        const int SEGMENTS = 32;
        for (int i = 0; i < SEGMENTS; i++) {
            float angle1 = i * 2 * PI / SEGMENTS;
            float angle2 = (i + 1) * 2 * PI / SEGMENTS;
            
            // XY plane
            buf.drawLine(
                Point(cos(angle1), sin(angle1)),
                Point(cos(angle2), sin(angle2))
            );
            
            // XZ plane
            buf.drawLine(
                Point(cos(angle1), 0, sin(angle1)),
                Point(cos(angle2), 0, sin(angle2))
            );
            
            // YZ plane
            buf.drawLine(
                Point(0, cos(angle1), sin(angle1)),
                Point(0, cos(angle2), sin(angle2))
            );
        }
    }
    
    private void drawCylinder(GLDrawBuf buf) {
        // Draw cylinder wireframe
        buf.setColor(0xFFFFFF);
        
        // Draw circles at top and bottom
        const int SEGMENTS = 16;
        for (int i = 0; i < SEGMENTS; i++) {
            float angle1 = i * 2 * PI / SEGMENTS;
            float angle2 = (i + 1) * 2 * PI / SEGMENTS;
            
            // Bottom circle
            buf.drawLine(
                Point(0.5f * cos(angle1), -1, 0.5f * sin(angle1)),
                Point(0.5f * cos(angle2), -1, 0.5f * sin(angle2))
            );
            
            // Top circle
            buf.drawLine(
                Point(0.5f * cos(angle1), 1, 0.5f * sin(angle1)),
                Point(0.5f * cos(angle2), 1, 0.5f * sin(angle2))
            );
            
            // Vertical lines
            buf.drawLine(
                Point(0.5f * cos(angle1), -1, 0.5f * sin(angle1)),
                Point(0.5f * cos(angle1), 1, 0.5f * sin(angle1))
            );
        }
    }
    
    private void drawGrid(GLDrawBuf buf) {
        // Draw grid lines
        buf.setColor(0x808080);
        for(int i = -5; i <= 5; i++) {
            buf.drawLine(Point(i, 0, -5), Point(i, 0, 5));
            buf.drawLine(Point(-5, 0, i), Point(5, 0, i));
        }
    }
    
    JSONValue toJSON() const {
        return JSONValue([
            "id": JSONValue(id),
            "type": JSONValue(type.to!string),
            "position": JSONValue([
                "x": JSONValue(position.x),
                "y": JSONValue(position.y),
                "z": JSONValue(position.z)
            ]),
            "rotation": JSONValue([
                "x": JSONValue(rotation.x),
                "y": JSONValue(rotation.y),
                "z": JSONValue(rotation.z)
            ]),
            "scale": JSONValue([
                "x": JSONValue(scale.x),
                "y": JSONValue(scale.y),
                "z": JSONValue(scale.z)
            ])
        ]);
    }
} 

 