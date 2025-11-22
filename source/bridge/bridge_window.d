module bridge.bridge_window;

import dlangui;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.platforms.common.platform;
import dlangui.graphics.gldrawbuf;
import dlangui.core.types;
import dlangui.core.logger;
import std.json;
import vibe.http.client;

import bindbc.sdl;
import bindbc.opengl;
import bridge.gl_utils;
import std.math : cos, sin, PI, tan;
import std.algorithm : clamp;
import std.string : toStringz, fromStringz;
import std.conv : to;

// Load OpenGL functions
private bool loadGL() {
    bindbc.opengl.GLSupport retVal = bindbc.opengl.loadOpenGL();
    
    if(retVal < bindbc.opengl.GLSupport.gl11) {
        Log.e("Bridge3DView: Failed to load OpenGL version 1.1 or higher. Support: ", retVal);
        return false;
    }
    Log.i("Bridge3DView: OpenGL loaded via bindbc-opengl. Support: ", retVal);
    return true;
}

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
    float zoomSpeed = 0.5f;
}

// Scene object with transform
class SceneObject {
    bridge.gl_utils.Vec3 position;
    bridge.gl_utils.Vec3 rotation;
    bridge.gl_utils.Vec3 scale;
    ObjectType type;
    string id;
    
    // OpenGL specific data
    GLuint vao = 0, vbo = 0, ebo = 0; // Vertex Array, Vertex Buffer, Element Buffer
    GLsizei vertexCount = 0; // Number of vertices or indices to draw
    float[] vertices; // CPU-side copy for now
    uint[] indices;   // CPU-side copy for now (optional)

    this(string id, ObjectType type) {
        this.id = id;
        this.type = type;
        position = bridge.gl_utils.vec3(0, 0, 0);
        rotation = bridge.gl_utils.vec3(0, 0, 0);
        scale = bridge.gl_utils.vec3(1, 1, 1);

        setupMesh();
    }
    
    // Create VAO/VBO for the object's mesh
    void setupMesh() {
        if (vao != 0) { // Already setup
            glDeleteVertexArrays(1, &vao);
            glDeleteBuffers(1, &vbo);
            if (ebo != 0) glDeleteBuffers(1, &ebo);
        }

        final switch(type) {
            case ObjectType.Cube:
                // X, Y, Z, R, G, B (interleaved)
                vertices = [
                    // Front face (red)
                    -0.5f, -0.5f,  0.5f,  1.0f, 0.0f, 0.0f,
                     0.5f, -0.5f,  0.5f,  1.0f, 0.0f, 0.0f,
                     0.5f,  0.5f,  0.5f,  1.0f, 0.0f, 0.0f,
                    -0.5f,  0.5f,  0.5f,  1.0f, 0.0f, 0.0f,
                    // Back face (green)
                    -0.5f, -0.5f, -0.5f,  0.0f, 1.0f, 0.0f,
                     0.5f, -0.5f, -0.5f,  0.0f, 1.0f, 0.0f,
                     0.5f,  0.5f, -0.5f,  0.0f, 1.0f, 0.0f,
                    -0.5f,  0.5f, -0.5f,  0.0f, 1.0f, 0.0f,
                    // ... add other faces with different colors for clarity ...
                    // Top face (blue)
                     -0.5f,  0.5f,  0.5f, 0.0f, 0.0f, 1.0f,
                      0.5f,  0.5f,  0.5f, 0.0f, 0.0f, 1.0f,
                      0.5f,  0.5f, -0.5f, 0.0f, 0.0f, 1.0f,
                     -0.5f,  0.5f, -0.5f, 0.0f, 0.0f, 1.0f,
                     // Bottom face (yellow)
                     -0.5f, -0.5f,  0.5f, 1.0f, 1.0f, 0.0f,
                      0.5f, -0.5f,  0.5f, 1.0f, 1.0f, 0.0f,
                      0.5f, -0.5f, -0.5f, 1.0f, 1.0f, 0.0f,
                     -0.5f, -0.5f, -0.5f, 1.0f, 1.0f, 0.0f,
                     // Right face (magenta)
                      0.5f, -0.5f,  0.5f, 1.0f, 0.0f, 1.0f,
                      0.5f, -0.5f, -0.5f, 1.0f, 0.0f, 1.0f,
                      0.5f,  0.5f, -0.5f, 1.0f, 0.0f, 1.0f,
                      0.5f,  0.5f,  0.5f, 1.0f, 0.0f, 1.0f,
                     // Left face (cyan)
                     -0.5f, -0.5f,  0.5f, 0.0f, 1.0f, 1.0f,
                     -0.5f, -0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
                     -0.5f,  0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
                     -0.5f,  0.5f,  0.5f, 0.0f, 1.0f, 1.0f,
                ];
                indices = [
                     0,  1,  2,  2,  3,  0, // Front
                     4,  5,  6,  6,  7,  4, // Back
                     8,  9, 10, 10, 11,  8, // Top
                    12, 13, 14, 14, 15, 12, // Bottom
                    16, 17, 18, 18, 19, 16, // Right
                    20, 21, 22, 22, 23, 20, // Left
                ];
                vertexCount = cast(GLsizei)indices.length;
                break;
            case ObjectType.Grid:
                // Grid lines
                int lines = 11; // -5 to +5
                float size = 5.0f;
                vertices.length = 0; // Clear
                for(int i = 0; i < lines; ++i) {
                    float pos = (cast(float)i / (lines - 1) - 0.5f) * 2.0f * size;
                    // X, Y, Z, R, G, B (grey color for grid)
                    vertices ~= [pos, 0.0f, -size,  0.5f, 0.5f, 0.5f];
                    vertices ~= [pos, 0.0f,  size,  0.5f, 0.5f, 0.5f];
                    vertices ~= [-size, 0.0f, pos,  0.5f, 0.5f, 0.5f];
                    vertices ~= [ size, 0.0f, pos,  0.5f, 0.5f, 0.5f];
                }
                indices.length = 0; // No EBO for grid lines, drawing directly
                vertexCount = cast(GLsizei)(vertices.length / 6); // Each line segment is 2 vertices
                break;
            case ObjectType.Sphere:
                // TODO: Implement sphere mesh
                Log.w("Sphere mesh not implemented yet in SceneObject.setupMesh");
                vertices.length = 0;
                indices.length = 0;
                vertexCount = 0;
                break;
            case ObjectType.Cylinder:
                // TODO: Implement cylinder mesh
                Log.w("Cylinder mesh not implemented yet in SceneObject.setupMesh");
                vertices.length = 0;
                indices.length = 0;
                vertexCount = 0;
                break;
        }

        if (vertices.length == 0 && type != ObjectType.Sphere && type != ObjectType.Cylinder) return; // Allow empty for unimplemented
        if (vertices.length == 0) return; // General check

        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        
        glBindVertexArray(vao);

        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof, vertices.ptr, GL_STATIC_DRAW);

        if (indices.length > 0) {
            glGenBuffers(1, &ebo);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof, indices.ptr, GL_STATIC_DRAW);
        }

        // Vertex Positions
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * float.sizeof, cast(void*)0);
        glEnableVertexAttribArray(0);
        // Vertex Colors
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * float.sizeof, cast(void*)(3 * float.sizeof));
        glEnableVertexAttribArray(1);

        glBindBuffer(GL_ARRAY_BUFFER, 0); // Unbind VBO
        glBindVertexArray(0); // Unbind VAO
    }
    
    // Clean up GPU resources
    void dispose() {
        if (vao != 0) glDeleteVertexArrays(1, &vao);
        if (vbo != 0) glDeleteBuffers(1, &vbo);
        if (ebo != 0) glDeleteBuffers(1, &ebo);
        vao = vbo = ebo = 0;
    }

    // Model matrix for this object
    bridge.gl_utils.Mat4 getModelMatrix() {
        bridge.gl_utils.Mat4 model = bridge.gl_utils.Mat4.identity();
        // Apply scale, then rotation, then translation (TRS)
        // This is a simplified TRS, a full matrix library would be better.
        // For now, we'll just do translation. Rotations/Scales need matrix math.
        // model = Mat4.scaling(scale.x, scale.y, scale.z) * model;
        // model = Mat4.rotationX(rotation.x) * model;
        // model = Mat4.rotationY(rotation.y) * model;
        // model = Mat4.rotationZ(rotation.z) * model;
        model = bridge.gl_utils.Mat4.translation(position.x, position.y, position.z) * model;
        return model;
    }

    JSONValue toJSON() {
        return JSONValue([
            "id": JSONValue(id),
            "type": JSONValue(to!string(type)),
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
    private bridge.gl_utils.Vec3 cameraPos;
    private bridge.gl_utils.Vec3 cameraRot;
    private float cameraFOV = 45.0f;
    
    private GLuint shaderProgram = 0;
    private GLint modelLoc, viewLoc, projLoc; // Uniform locations

    this() {
        super("bridge3d");
        cameraPos = bridge.gl_utils.vec3(0, 2, 10);
        cameraRot = bridge.gl_utils.vec3(0,0,0);
        backgroundColor = 0x202030;
        
        // Use layoutFinished signal
        this.layoutFinished.connect( { initGL(); addDefaultObjects(); } );
    }
    
    ~this() {
        if (shaderProgram != 0) glDeleteProgram(shaderProgram);
        foreach(obj; objects) obj.dispose();
    }

    // Initialize OpenGL resources (shaders, etc.)
    // This should be called after the GL context is available.
    void initGL() {
        if (shaderProgram != 0) return; // Already initialized

        // Check if GL is loaded, try to load if not (DLangUI usually handles this via GLDrawBuf)
        if (!glActiveTexture) { // A quick check if GL functions are loaded
            if (!loadGL()) { // bindbc-opengl's load function
                 Log.e("Bridge3DView: Failed to load OpenGL functions via local loadGL!");
                 return;
            }
        }
        
        shaderProgram = createShaderProgram("source/bridge/shaders/simple.vert", 
                                            "source/bridge/shaders/simple.frag");
        if (shaderProgram == 0) {
            Log.e("Failed to create shader program!");
            return;
        }

        modelLoc = glGetUniformLocation(shaderProgram, "model");
        viewLoc  = glGetUniformLocation(shaderProgram, "view");
        projLoc  = glGetUniformLocation(shaderProgram, "projection");
        Log.d("Shader program created. modelLoc: ", modelLoc, " viewLoc: ", viewLoc, " projLoc: ", projLoc);
    }
    
    private void addDefaultObjects() {
        auto grid = new SceneObject("grid", ObjectType.Grid);
        objects ~= grid;
        
        auto cube = new SceneObject("demo_cube", ObjectType.Cube);
        cube.position = bridge.gl_utils.vec3(0, 0.5f, 0);
        objects ~= cube;

        invalidate();
    }
    
    override void onDraw(DrawBuf buf) {
        auto glbuf = cast(GLDrawBuf)buf;
        if (!glbuf) {
            // Log.e("GLDrawBuf not available"); // Removed drawText
            return;
        }
        if (shaderProgram == 0) {
             initGL(); // Try to init if not done (e.g. on first draw)
             if (shaderProgram == 0) {
                // Log.e("Shader Program Failed to Initialize"); // Removed drawText
                return;
             }
        }
        
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glCullFace(GL_BACK);
        
        uint bg = backgroundColor;
        glClearColor(((bg >> 16) & 0xFF)/255.0f, ((bg >> 8) & 0xFF)/255.0f, (bg & 0xFF)/255.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glUseProgram(shaderProgram);

        // Projection matrix
        float aspect = (height > 0) ? (cast(float)width / cast(float)height) : 1.0f;
        bridge.gl_utils.Mat4 projection = bridge.gl_utils.Mat4.perspective(cameraFOV * (PI / 180.0f), aspect, 0.1f, 100.0f);
        glUniformMatrix4fv(projLoc, 1, GL_FALSE, projection.M.ptr);

        // View matrix (camera)
        bridge.gl_utils.Mat4 view = bridge.gl_utils.Mat4.identity();
        // Apply rotations (order: Yaw, Pitch, Roll for FPS-like camera)
        // This is a simplified view matrix. Proper camera needs more robust math.
        view = bridge.gl_utils.Mat4.translation(-cameraPos.x, -cameraPos.y, -cameraPos.z) * view; // Translate
        glUniformMatrix4fv(viewLoc, 1, GL_FALSE, view.M.ptr);

        // Draw objects
        foreach(obj; objects) {
            if (obj.vao == 0) continue; // Skip if mesh not ready

            bridge.gl_utils.Mat4 model = obj.getModelMatrix();
            glUniformMatrix4fv(modelLoc, 1, GL_FALSE, model.M.ptr);

            glBindVertexArray(obj.vao);
            if (obj.type == ObjectType.Grid) {
                glDrawArrays(GL_LINES, 0, obj.vertexCount);
            } else if (obj.indices.length > 0) {
                glDrawElements(GL_TRIANGLES, obj.vertexCount, GL_UNSIGNED_INT, null);
            } else {
                glDrawArrays(GL_TRIANGLES, 0, obj.vertexCount); // Fallback if no indices but not lines
            }
            glBindVertexArray(0);
        }
        glUseProgram(0); // Unbind shader

        // Restore OpenGL state modified
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
    }
    
    override bool onMouseEvent(MouseEvent event) {
        bool handled = false;
         switch(event.action) {
            case MouseAction.ButtonDown:
                if (event.button == MouseButton.Left) {
                    control.rotating = true;
                    control.lastMousePos = Point(event.x, event.y);
                    handled = true;
                } else if (event.button == MouseButton.Right) {
                    control.panning = true;
                    control.lastMousePos = Point(event.x, event.y);
                    handled = true;
                }
                break;
                
            case MouseAction.ButtonUp:
                if (event.button == MouseButton.Left && control.rotating) {
                    control.rotating = false;
                    handled = true;
                } else if (event.button == MouseButton.Right && control.panning) {
                    control.panning = false;
                    handled = true;
                }
                break;
                
            case MouseAction.Move:
                if (control.rotating) {
                    float dx = (event.x - control.lastMousePos.x);
                    float dy = (event.y - control.lastMousePos.y);
                    cameraRot.y += dx * control.rotationSpeed;
                    cameraRot.x += dy * control.rotationSpeed;
                    // Clamp pitch to avoid flipping
                    cameraRot.x = clamp(cameraRot.x, -PI/2.0f + 0.01f, PI/2.0f - 0.01f);
                    control.lastMousePos = Point(event.x, event.y);
                    invalidate();
                    handled = true;
                } else if (control.panning) {
                    // Simple panning for now, a proper implementation would consider camera orientation
                    float dx = (event.x - control.lastMousePos.x) * control.panSpeed;
                    float dy = (event.y - control.lastMousePos.y) * control.panSpeed;
                    cameraPos.x -= dx;
                    cameraPos.y += dy;
                    control.lastMousePos = Point(event.x, event.y);
                    invalidate();
                    handled = true;
                }
                break;
                
            case MouseAction.Wheel:
                cameraPos.z -= event.wheelDelta * control.zoomSpeed;
                invalidate();
                handled = true;
                break;
            default: break;
        }
        return handled;
    }
    
    void updateFromState(JSONValue state) {
        if ("camera" in state) {
            auto cam = state["camera"];
            cameraPos = bridge.gl_utils.vec3(
                cam["position"]["x"].floating,
                cam["position"]["y"].floating,
                cam["position"]["z"].floating
            );
            cameraRot = bridge.gl_utils.vec3(
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
    private vibe.http.client.WebSocketClient ws;
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
            viewTab.addChild(new TextWidget(null, "Field of View (Deg)"d));
            auto fovSlider = new SliderWidget("fov");
            fovSlider.setRange(30, 120);
            fovSlider.position = cast(int)mainView.cameraFOV;
            fovSlider.onPositionChanged = &onFOVChanged;
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
        mainView.cameraPos = bridge.gl_utils.vec3(0, 2, 10);
        mainView.cameraRot = bridge.gl_utils.vec3(0, 0, 0);
        mainView.cameraFOV = 45.0f;
        if(auto fovSlider = cast(SliderWidget)tabs.findChildRecursive("fov")) {
            fovSlider.position = cast(int)mainView.cameraFOV;
        }
        mainView.invalidate();
        sendCameraState();
        return true;
    }
    
    private bool onFOVChanged(Widget sliderWidget, int newPosition) {
        mainView.cameraFOV = newPosition;
        mainView.invalidate();
        sendCameraState();
        return true;
    }
    
    private void sendCameraState() {
        if (!ws || ws.readyState != vibe.http.client.WebSocketReadyState.Open) return;
        
        auto cam = mainView.cameraPos;
        auto rot = mainView.cameraRot;
        auto fov = mainView.cameraFOV;
        ws.send(JSONValue([
            "type": JSONValue("camera_updated"),
            "camera": JSONValue([
                "position": JSONValue([
                    "x": JSONValue(cam.x),
                    "y": JSONValue(cam.y),
                    "z": JSONValue(cam.z)
                ]),
                "rotation": JSONValue([
                    "x": JSONValue(rot.x),
                    "y": JSONValue(rot.y),
                    "z": JSONValue(rot.z)
                ]),
                "fov": JSONValue(fov)
            ])
        ]).toString());
    }
    
    private void connectWebSocket() {
        try {
            // Ensure vibe.d's event loop is running if not already handled by DLangUI/Platform
            // runTask is for vibe.d's fiber-based tasks. DLangUI usually runs its own main loop.
            // Direct call should be fine if vibe.d's event driver is compatible or started.
            Log.i("Attempting to connect WebSocket to ws://localhost:4040/bridge");
            ws = vibe.http.client.connectWebSocketClient("ws://localhost:4040/bridge");
            Log.i("WebSocket connectWebSocketClient called.");

            // WebSocketClient uses onTextMessage, onBinaryMessage, onError, onClose
            ws.onTextMessage = &onWebSocketTextMessage;
            ws.onClose = { 
                Log.i("WebSocket connection closed."); 
                // Optionally try to reconnect or update UI
            };
            // ws.onError = (string message) { Log.e("WebSocket error: ", message); };
            Log.i("WebSocket event handlers assigned.");
            
        } catch (Exception e) {
            Log.e("WebSocket connection error: ", e.msg);
            Log.e("Full error: ", e.toString());
        }
    }
    
    private void onWebSocketTextMessage(string message) { 
        try {
            Log.d("WebSocket message received: ", message);
            auto state = parseJSON(message);
            // Ensure state is not null and has expected structure before accessing
            if (state.type != JSONType.null_) {
                 mainView.updateFromState(state);
            } else {
                Log.w("Parsed JSON state is null from message: ", message);
            }
        } catch (JSONException e) {
            Log.e("WebSocket JSON parsing error: ", e.msg, " for message: ", message);
        } catch (Exception e) {
            Log.e("WebSocket message processing error: ", e.msg);
        }
    }
    
    private bool onLayoutChanged(Widget source, int itemIndex) {
        if (!ws || ws.readyState != vibe.http.client.WebSocketReadyState.Open) return false;
        
        // Send layout change to Gleam
        auto comboBox = cast(ComboBox)source;
        if (comboBox) {
            ws.send(JSONValue([
                "type": JSONValue("layout_changed"),
                "layout": JSONValue(comboBox.items[itemIndex])
            ]).toString());
        }
        return true;
    }
    
    override void show() {
        auto window = Platform.instance.createWindow(
            windowCaption,
            null,
            WindowFlag.Resizable,
            1024,
            768
        );
        
        if (window && mainWidget) {
            window.mainWidget = mainWidget;
            window.show();
        }
    }
    
    override void close() {
        if (ws && ws.readyState == vibe.http.client.WebSocketReadyState.Open) {
            ws.close();
        }
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

 