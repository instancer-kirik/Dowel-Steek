module stash.scene;

import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;
import std.json;

// Basic 3D object types
enum ObjectType {
    Cube,
    Sphere,
    Cylinder,
    Grid
}

// Scene object with transform
class SceneObject {
    Vec3 position;
    Vec3 rotation;
    Vec3 scale;
    ObjectType type;
    string id;
    
    this(string id, ObjectType type) {
        this.id = id;
        this.type = type;
        position = Vec3(0, 0, 0);
        rotation = Vec3(0, 0, 0);
        scale = Vec3(1, 1, 1);
    }
    
    void render(GLDrawBuf buf) {
        // Basic rendering based on type
        buf.pushMatrix();
        buf.translate(position.x, position.y, position.z);
        buf.rotate(rotation.x, rotation.y, rotation.z);
        buf.scale(scale.x, scale.y, scale.z);
        
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
        
        buf.popMatrix();
    }

    private void drawCube(GLDrawBuf buf) {
        // Simple cube wireframe
        buf.drawRect3D(Vec3(-1, -1, -1), Vec3(1, 1, 1), 0xFFFFFF);
    }
    
    private void drawSphere(GLDrawBuf buf) {
        // Simple sphere approximation
        buf.drawEllipse3D(Vec3(0, 0, 0), 1.0f, 1.0f, 0xFFFFFF);
    }
    
    private void drawCylinder(GLDrawBuf buf) {
        // Simple cylinder approximation
        buf.drawRect3D(Vec3(-0.5, -1, -0.5), Vec3(0.5, 1, 0.5), 0xFFFFFF);
    }
    
    private void drawGrid(GLDrawBuf buf) {
        // Draw grid lines
        for(int i = -5; i <= 5; i++) {
            buf.drawLine3D(Vec3(i, 0, -5), Vec3(i, 0, 5), 0x808080);
            buf.drawLine3D(Vec3(-5, 0, i), Vec3(5, 0, i), 0x808080);
        }
    }
    
    JSONValue toJSON() {
        return JSONValue([
            "id": JSONValue(id),
            "type": JSONValue(cast(string)type),
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

 