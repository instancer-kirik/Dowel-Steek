module bridge.bridge_window;

import dlangui;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.platforms.common.platform;
import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;
import dlangui.core.types;
import std.json;
import vibe.d;
import bridge.scene3d;
import bindbc.sdl;
import bindbc.opengl;

// Basic 3D object types
enum ObjectType {
    Cube,
    Sphere,
    Cylinder,
    Grid
}

// Camera control state
private struct CameraControl {
    bool rotating = false;
    bool panning = false;
    Point lastMousePos;
    float rotationSpeed = 0.01f;
    float panSpeed = 0.1f;
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
        buf.drawRect3D(vec3(-1, -1, -1), vec3(1, 1, 1), 0xFFFFFF);
    }
    
    private void drawSphere(GLDrawBuf buf) {
        // Simple sphere approximation
        buf.drawEllipse3D(vec3(0, 0, 0), 1.0f, 1.0f, 0xFFFFFF);
    }
    
    private void drawCylinder(GLDrawBuf buf) {
        // Simple cylinder approximation
        buf.drawRect3D(vec3(-0.5, -1, -0.5), vec3(0.5, 1, 0.5), 0xFFFFFF);
    }
    
    private void drawGrid(GLDrawBuf buf) {
        // Draw grid lines
        for(int i = -5; i <= 5; i++) {
            buf.drawLine3D(vec3(i, 0, -5), vec3(i, 0, 5), 0x808080);
            buf.drawLine3D(vec3(-5, 0, i), vec3(5, 0, i), 0x808080);
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

// 3D View widget for Bridge
class Bridge3DView : Widget {
    private SceneObject[] objects;
    private CameraControl control;
    private vec3 cameraPos;
    private vec3 cameraRot;
    private float cameraFOV = 45.0f;
    
    this() {
        super("bridge3d");
        cameraPos = vec3(0, 0, 10);
        backgroundColor = 0x2D2D2D;
        
        // Add default objects
        addDefaultObjects();
    }
    
    private void addDefaultObjects() {
        // Add reference grid
        auto grid = new SceneObject("grid", ObjectType.Grid);
        grid.position = vec3(0, -2, 0);
        objects ~= grid;
        
        // Add demo cube
        auto cube = new SceneObject("demo_cube", ObjectType.Cube);
        cube.position = vec3(0, 0, 0);
        objects ~= cube;
    }
    
    override void onDraw(DrawBuf buf) {
        auto glbuf = cast(GLDrawBuf)buf;
        if (!glbuf)
            return;

        // Set up OpenGL state
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
        
        // Clear buffers
        glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        // Set up projection matrix
        float aspect = cast(float)width / cast(float)height;
        mat4 projection;
        projection.setPerspective(cameraFOV, aspect, 0.1f, 100.0f);
        
        // Set up view matrix
        mat4 view;
        view.setIdentity();
        view.translate(-cameraPos.x, -cameraPos.y, -cameraPos.z);
        view.rotate(cameraRot.x, 1, 0, 0);
        view.rotate(cameraRot.y, 0, 1, 0);
        view.rotate(cameraRot.z, 0, 0, 1);

        // Draw objects
        foreach(obj; objects) {
            // Set up model matrix
            mat4 model;
            model.setIdentity();
            model.translate(obj.position.x, obj.position.y, obj.position.z);
            model.rotate(obj.rotation.x, 1, 0, 0);
            model.rotate(obj.rotation.y, 0, 1, 0);
            model.rotate(obj.rotation.z, 0, 0, 1);
            model.scale(obj.scale.x, obj.scale.y, obj.scale.z);

            // Combine matrices
            mat4 mvp = projection * view * model;

            // Draw object
            final switch(obj.type) {
                case ObjectType.Cube:
                    drawCube(mvp);
                    break;
                case ObjectType.Sphere:
                    drawSphere(mvp);
                    break;
                case ObjectType.Cylinder:
                    drawCylinder(mvp);
                    break;
                case ObjectType.Grid:
                    drawGrid(mvp);
                    break;
            }
        }

        // Restore OpenGL state
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
    }

    private void drawCube(mat4 mvp) {
        // Simple cube vertices
        static immutable float[] vertices = [
            // Front face
            -1, -1,  1,
             1, -1,  1,
             1,  1,  1,
            -1,  1,  1,
            // Back face
            -1, -1, -1,
            -1,  1, -1,
             1,  1, -1,
             1, -1, -1,
        ];

        // Draw cube wireframe
        glColor3f(1.0f, 1.0f, 1.0f);
        glBegin(GL_LINE_LOOP);
        foreach(i; 0..4) {
            glVertex3f(vertices[i*3], vertices[i*3+1], vertices[i*3+2]);
        }
        glEnd();
        glBegin(GL_LINE_LOOP);
        foreach(i; 4..8) {
            glVertex3f(vertices[i*3], vertices[i*3+1], vertices[i*3+2]);
        }
        glEnd();
    }

    private void drawGrid(mat4 mvp) {
        glColor3f(0.5f, 0.5f, 0.5f);
        glBegin(GL_LINES);
        for(int i = -5; i <= 5; i++) {
            glVertex3f(i, 0, -5);
            glVertex3f(i, 0,  5);
            glVertex3f(-5, 0, i);
            glVertex3f( 5, 0, i);
        }
        glEnd();
    }

    private void drawSphere(mat4 mvp) {
        // Simplified sphere as point for now
        glColor3f(1.0f, 1.0f, 1.0f);
        glPointSize(5.0f);
        glBegin(GL_POINTS);
        glVertex3f(0, 0, 0);
        glEnd();
    }

    private void drawCylinder(mat4 mvp) {
        // Simplified cylinder as line for now
        glColor3f(1.0f, 1.0f, 1.0f);
        glBegin(GL_LINES);
        glVertex3f(0, -1, 0);
        glVertex3f(0,  1, 0);
        glEnd();
    }
    
    override bool onMouseEvent(MouseEvent event) {
        switch(event.action) {
            case MouseAction.ButtonDown:
                if (event.button == MouseButton.Left) {
                    control.rotating = true;
                    control.lastMousePos = Point(event.x, event.y);
                    return true;
                }
                if (event.button == MouseButton.Right) {
                    control.panning = true;
                    control.lastMousePos = Point(event.x, event.y);
                    return true;
                }
                break;
                
            case MouseAction.ButtonUp:
                if (event.button == MouseButton.Left)
                    control.rotating = false;
                if (event.button == MouseButton.Right)
                    control.panning = false;
                return true;
                
            case MouseAction.Move:
                if (control.rotating) {
                    float dx = (event.x - control.lastMousePos.x) * control.rotationSpeed;
                    float dy = (event.y - control.lastMousePos.y) * control.rotationSpeed;
                    cameraRot.y += dx;
                    cameraRot.x += dy;
                    control.lastMousePos = Point(event.x, event.y);
                    invalidate();
                    return true;
                }
                if (control.panning) {
                    float dx = (event.x - control.lastMousePos.x) * control.panSpeed;
                    float dy = (event.y - control.lastMousePos.y) * control.panSpeed;
                    cameraPos.x -= dx;
                    cameraPos.y += dy;
                    control.lastMousePos = Point(event.x, event.y);
                    invalidate();
                    return true;
                }
                break;
                
            case MouseAction.Wheel:
                cameraPos.z += event.wheelDelta * 0.5f;
                invalidate();
                return true;
                
            default:
                break;
        }
        return false;
    }
    
    void updateFromState(JSONValue state) {
        if ("camera" in state) {
            auto cam = state["camera"];
            cameraPos = vec3(
                cam["position"]["x"].floating,
                cam["position"]["y"].floating,
                cam["position"]["z"].floating
            );
            cameraRot = vec3(
                cam["rotation"]["x"].floating,
                cam["rotation"]["y"].floating,
                cam["rotation"]["z"].floating
            );
            cameraFOV = cam["fov"].floating;
            invalidate();
        }
    }
}

// Main Bridge window
class BridgeWindow : Window {
    private Bridge3DView mainView;
    private VerticalLayout sidePanel;
    private WebSocket ws;
    private TabWidget tabs;
    
    this() {
        super();
        
        try {
            // Create main layout
            auto mainLayout = new HorizontalLayout();
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            
            // Create 3D view
            mainView = new Bridge3DView();
            mainView.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            mainLayout.addChild(mainView);
            
            // Create side panel with tabs
            tabs = new TabWidget("tabs");
            tabs.layoutWidth = 250;
            tabs.layoutHeight = FILL_PARENT;
            
            // Layout tab
            auto layoutTab = new VerticalLayout();
            layoutTab.padding(Rect(8, 8, 8, 8));
            layoutTab.backgroundColor = 0x1E1E1E;
            
            auto layoutSelector = new ComboBox("layouts");
            layoutSelector.items = ["Default", "Split", "Quad"];
            layoutSelector.selectedItemIndex = 0;
            layoutSelector.itemClick = &onLayoutChanged;
            layoutTab.addChild(layoutSelector);
            
            // View controls tab
            auto viewTab = new VerticalLayout();
            viewTab.padding(Rect(8, 8, 8, 8));
            viewTab.backgroundColor = 0x1E1E1E;
            
            // Add camera controls
            viewTab.addChild(new TextWidget(null, "Camera Controls"d));
            auto resetBtn = new Button("reset", "Reset Camera"d);
            resetBtn.click = &onResetCamera;
            viewTab.addChild(resetBtn);
            
            // Add FOV slider
            viewTab.addChild(new TextWidget(null, "Field of View"d));
            auto fovSlider = new SliderWidget("fov");
            fovSlider.setRange(30, 120);
            fovSlider.position = 45;
            fovSlider.change = &onFOVChanged;
            viewTab.addChild(fovSlider);
            
            // Add tabs
            tabs.addTab(layoutTab, "Layout"d);
            tabs.addTab(viewTab, "View"d);
            
            mainLayout.addChild(tabs);
            
            // Set main widget
            mainWidget = mainLayout;
            
            // Connect to Gleam backend
            connectWebSocket();
            
        } catch (Exception e) {
            Log.e("BridgeWindow init error: ", e.msg);
        }
    }
    
    private bool onResetCamera(Widget w) {
        mainView.cameraPos = vec3(0, 0, 10);
        mainView.cameraRot = vec3(0, 0, 0);
        mainView.invalidate();
        sendCameraState();
        return true;
    }
    
    private bool onFOVChanged(Widget w) {
        auto slider = cast(SliderWidget)w;
        if (slider) {
            mainView.cameraFOV = slider.position;
            mainView.invalidate();
            sendCameraState();
        }
        return true;
    }
    
    private void sendCameraState() {
        if (!ws) return;
        
        auto cam = mainView.cameraPos;
        auto rot = mainView.cameraRot;
        auto fov = mainView.cameraFOV;
        ws.send(JSONValue([
            "type": JSONValue("camera_updated"),
            "camera": JSONValue([
                "position": JSONValue([
                    "x": cam.x,
                    "y": cam.y,
                    "z": cam.z
                ]),
                "rotation": JSONValue([
                    "x": rot.x,
                    "y": rot.y,
                    "z": rot.z
                ]),
                "fov": fov
            ])
        ]).toString());
    }
    
    private void connectWebSocket() {
        try {
            ws = connectWebSocket("ws://localhost:4040/bridge");
            ws.onMessage = &onWebSocketMessage;
        } catch (Exception e) {
            Log.e("WebSocket connection error: ", e.msg);
        }
    }
    
    private void onWebSocketMessage(scope WebSocket ws, string message) {
        try {
            auto state = parseJSON(message);
            mainView.updateFromState(state);
        } catch (Exception e) {
            Log.e("WebSocket message error: ", e.msg);
        }
    }
    
    private bool onLayoutChanged(Widget source, int itemIndex) {
        if (!ws) return false;
        
        // Send layout change to Gleam
        ws.send(JSONValue([
            "type": JSONValue("layout_changed"),
            "layout": JSONValue(source.text.toString())
        ]).toString());
        
        return true;
    }
    
    override void show() {
        auto window = Platform.instance.createWindow(
            windowCaption,
            null,
            WindowFlag.Resizable,
            800,
            600
        );
        
        if (window && mainWidget) {
            window.mainWidget = mainWidget;
            window.show();
        }
    }
    
    override void close() {
        if (ws) ws.close();
        Platform.instance.closeWindow(this);
    }
    
    override @property dstring windowCaption() const {
        return "Bridge"d;
    }
    
    // Other required Window overrides
    override void invalidate() {
        if (mainWidget) mainWidget.invalidate();
    }
    
    override @property void windowCaption(dstring caption) {}
    override @property void windowIcon(DrawBufRef icon) {}
} 

 