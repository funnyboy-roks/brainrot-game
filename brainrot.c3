import std::io;
import raylib::rl;
import std::collections::list;

struct Light {
    int type;
    bool enabled;
    rl::Vector3 position;
    rl::Vector3 target;
    rl::Color color;
    float attenuation;
    
    // Shader locations
    int enabledLoc;
    int typeLoc;
    int positionLoc;
    int targetLoc;
    int colorLoc;
    int attenuationLoc;
}

const int MAX_LIGHTS = 4; 

// Light type
enum LightType {
    LIGHT_DIRECTIONAL,
    LIGHT_POINT,
}

int lightsCount = 0;    // Current amount of created lights
fn Light create_light(int type, Vector3 position, Vector3 target, Color color, Shader shader)
{
    Light light;

    if (lightsCount < MAX_LIGHTS)
    {
        light.enabled = true;
        light.type = type;
        light.position = position;
        light.target = target;
        light.color = color;

        // NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc = rl::getShaderLocation(shader, rl::textFormat("lights[%i].enabled", lightsCount));
        light.typeLoc = rl::getShaderLocation(shader, rl::textFormat("lights[%i].type", lightsCount));
        light.positionLoc = rl::getShaderLocation(shader, rl::textFormat("lights[%i].position", lightsCount));
        light.targetLoc = rl::getShaderLocation(shader, rl::textFormat("lights[%i].target", lightsCount));
        light.colorLoc = rl::getShaderLocation(shader, rl::textFormat("lights[%i].color", lightsCount));

        update_light_values(shader, light);
        
        lightsCount++;
    }

    return light;
}

// Send light properties to shader
// NOTE: Light shader locations should be available 
fn void update_light_values(Shader shader, Light light)
{
    // Send to shader light enabled state and type
    rl::setShaderValue(shader, light.enabledLoc, &light.enabled, rl::SHADER_UNIFORM_INT);
    rl::setShaderValue(shader, light.typeLoc, &light.type, rl::SHADER_UNIFORM_INT);

    // Send to shader light position values
    float[*] position = { light.position.x, light.position.y, light.position.z };
    rl::setShaderValue(shader, light.positionLoc, &position, rl::SHADER_UNIFORM_VEC3);

    // Send to shader light target position values
    float[*] target = { light.target.x, light.target.y, light.target.z };
    rl::setShaderValue(shader, light.targetLoc, &target, rl::SHADER_UNIFORM_VEC3);

    // Send to shader light color values
    float[*] color = { (float)light.color.r/(float)255, (float)light.color.g/(float)255, 
                       (float)light.color.b/(float)255, (float)light.color.a/(float)255 };

   rl::setShaderValue(shader, light.colorLoc, &color, rl::SHADER_UNIFORM_VEC4);
}

fn Vector3 Vector3.add(self, Vector3 other) @operator(+) => { self.x + other.x, self.y + other.y, self.z + other.z };
fn Vector3 Vector3.sub(self, Vector3 other) @operator(-) => { self.x - other.x, self.y - other.y, self.z - other.z };

struct Target {
    Vector3 pos;
    int left;
    int right;
}

fn void main()
{
    rl::initWindow(800, 600, "Brainrot");

    rl::Camera camera;
    camera.position   = { 30, 10,  0 };         // Camera position
    camera.target     = {  0,  0,  0 };         // Camera looking at point
    camera.up         = {  0,  1,  0 };         // Camera up vector (rotation towards target)
    camera.fovy       = 45;                     // Camera field-of-view Y
    camera.projection = rl::CAMERA_PERSPECTIVE; // Camera projection type


    // Load basic lighting shader
    Shader shader = rl::loadShader("shaders/lighting.vs", "shaders/lighting.fs");
    shader.locs[rl::SHADER_LOC_VECTOR_VIEW] = rl::getShaderLocation(shader, "viewPos");

    // Ambient light level (some basic lighting)
    int ambient_loc = rl::getShaderLocation(shader, "ambient");
    rl::setShaderValue(shader, ambient_loc, &&(float[4]){ 1.0f, 1.0f, 1.0f, 1.0f }, rl::SHADER_UNIFORM_VEC4);

    Light sun = create_light(LightType.LIGHT_DIRECTIONAL.ordinal, { 30, 10, -10 }, {}, rl::WHITE, shader);

    rl::disableCursor();

    Vector3 position = { 15, 0.25, 0 };
    List{Target} targets;
    targets.tinit();

    float start = 10;
    float gap = 30;
    for (int i = 0; i < 10; i++) {
        targets.push({
            .pos = { -(start + (float)i * gap), 0.25, 0 },
            .left = -50,
            .right = 50,
        });
    }

    rl::setTargetFPS(60);
    while (!rl::windowShouldClose()) {
        rl::updateCamera(&camera, rl::CAMERA_THIRD_PERSON);

        // Update the shader with the camera view vector (points towards { 0.0f, 0.0f, 0.0f })
        float[3] camera_pos = { camera.position.x, camera.position.y, camera.position.z };
        rl::setShaderValue(shader, shader.locs[rl::SHADER_LOC_VECTOR_VIEW], &camera_pos, rl::SHADER_UNIFORM_VEC3);

        update_light_values(shader, sun);

        rl::beginDrawing();
            rl::clearBackground(rl::SKYBLUE);

            Vector3 speed = { 0, 0, 0.2 };

            if (rl::isKeyDown(rl::KEY_LEFT)) position += speed;
            if (rl::isKeyDown(rl::KEY_RIGHT)) position -= speed;

            rl::beginMode3D(camera); rl::beginShaderMode(shader);
                // platform
                rl::drawCube({-125, 0, 0}, 300, 0.5, 20, rl::RAYWHITE);

                float player_height = 2;

                rl::drawCube(
                    position + (Vector3){ 0, player_height/2, 0 },
                    player_height, player_height, player_height,
                    rl::RED,
                );

                foreach (&target : targets) {
                    rl::drawCube(
                        target.pos + (Vector3){ 0, 3.0/2, 5 },
                        0.25, 3, 10,
                        target.left < 0 ? rl::RED : rl::GREEN,
                    );

                    rl::drawCube(
                        target.pos + (Vector3){ 0, 3.0/2, -5 },
                        0.25, 3, 10,
                        target.right < 0 ? rl::RED : rl::GREEN,
                    );

                    target.pos.x += 0.75;

                    if (target.pos.x > gap) {
                        target.pos.x = -(start + 9 * gap);
                    }
                }

            rl::endShaderMode(); rl::endMode3D();

            usz max_i = 0;
            float max = 0;
            foreach (i, target : targets) {
                if (target.pos.x > max) {
                    max = target.pos.x;
                    max_i = i;
                }
            }

            Target target = targets[max_i];

            rl::Vector2 mid = rl::getWorldToScreen(
                target.pos + (Vector3){ 0, 3.0/2, 5 },
                camera
            );

            rl::drawText(
                rl::textFormat("HI", target.left),
                (int)mid.x, (int)mid.y,
                30,
                rl::BLACK,
            );
        rl::endDrawing();
    }

    rl::unloadShader(shader);
    rl::closeWindow();
}
