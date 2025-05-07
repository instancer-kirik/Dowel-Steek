module D;

import dlangui;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.platforms.common.platform;
import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;
import dlangui.core.types;
import bridge.scene3d;
import bridge.bridge_window;
import bindbc.opengl;
import dlangui.core.logger;

class MainWindow : Window {
    private Scene3DWidget scene;
    private VerticalLayout sidePanel;
    private TabWidget tabs;
    
    this() {
        super();  // Call base constructor without parameters
        
        try {
            // Create main layout
            auto mainLayout = new HorizontalLayout();
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            
            // Create 3D scene view
            scene = new Scene3DWidget();
            scene.layoutWidth = FILL_PARENT;
            scene.layoutHeight = FILL_PARENT;
            mainLayout.addChild(scene);
            
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
            fovSlider.onSliderChange = &onFOVChanged;  // Fixed event handler name
            viewTab.addChild(fovSlider);
            
            // Add tabs
            tabs.addTab(layoutTab, "Layout"d);
            tabs.addTab(viewTab, "View"d);
            
            mainLayout.addChild(tabs);
            
            // Set main widget
            mainWidget = mainLayout;
            
        } catch (Exception e) {
            Log.e("MainWindow init error: ", e.msg);
        }
    }
    
    private bool onResetCamera(Widget w) {
        if (scene) {
            scene.resetCamera();
            return true;
        }
        return false;
    }
    
    private bool onFOVChanged(Widget source, int value) {  // Fixed signature
        if (scene) {
            scene.setFOV(cast(float)value);
            return true;
        }
        return false;
    }
    
    private bool onLayoutChanged(Widget source, int itemIndex) {
        if (scene) {
            scene.setLayout(itemIndex);
            return true;
        }
        return false;
    }
    
    override void show() {
        // Create window using correct API
        auto win = Platform.instance.createWindow("3D Scene Editor"d, null,
            WindowFlag.Resizable, 1280, 720);
        if (win)
            win.mainWidget = this;
    }

    // Implement required abstract methods
    override @property dstring windowCaption() const {
        return "3D Scene Editor"d;
    }

    override @property void windowCaption(dstring caption) {
        // Ignore caption changes
    }

    override @property void windowIcon(DrawBufRef icon) {
        // Ignore icon changes
    }

    override void invalidate() {
        if (mainWidget)
            mainWidget.invalidate();
    }

    override void close() {
        Platform.instance.closeWindow(this);
    }
}

// Custom 3D scene widget using DlangUI's OpenGL support
class Scene3DWidget : Widget {
    private SceneObject[] objects;
    private vec3 cameraPos = vec3(0, 0, 10);
    private vec3 cameraRot = vec3(0, 0, 0);
    private float cameraFOV = 45.0f;
    
    this() {
        super("scene3d");
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
        if (auto glbuf = cast(GLDrawBuf)buf) {
            // Set up OpenGL state
            glbuf.save();
            
            // Apply camera transform
            glbuf.translate(cameraPos.x, cameraPos.y, cameraPos.z);
            glbuf.rotateX(cameraRot.x);
            glbuf.rotateY(cameraRot.y);
            glbuf.rotateZ(cameraRot.z);
            
            // Draw objects
            foreach(obj; objects) {
                obj.render(glbuf);
            }
            
            glbuf.restore();
        }
    }
    
    void resetCamera() {
        cameraPos = vec3(0, 0, 10);
        cameraRot = vec3(0, 0, 0);
        invalidate();
    }
    
    void setFOV(float fov) {
        cameraFOV = fov;
        invalidate();
    }
    
    void setLayout(int layoutIndex) {
        // Update object layout based on selected index
        invalidate();
    }
    
    override bool onMouseEvent(MouseEvent event) {
        // Handle mouse input for camera control
        return true;
    }
    
    override bool onKeyEvent(KeyEvent event) {
        // Handle keyboard input for camera control
        return true;
    }
}

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {
    // Initialize DlangUI with SDL backend
    Platform.instance = Platform.create("sdl");
    if (!Platform.instance)
        return -1;
    
    // Create and show main window
    Window window = new MainWindow();
    window.show();
    
    // Run message loop
    return Platform.instance.enterMessageLoop();
}