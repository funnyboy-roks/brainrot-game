import std::io;
import raylib::rl;
import raylib::rlgl;
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
const float LETTER_BOUNDRY_SIZE = 0.25;
const Color LETTER_BOUNDRY_COLOR = rl::VIOLET;
const bool SHOW_LETTER_BOUNDRY = false;

fn void draw_text_codepoint_3d(
    Font font,
    int codepoint,
    Vector3 position,
    float fontSize,
    bool backface,
    Color tint
) {
    // Character index position in sprite font
    // NOTE: In case a codepoint is not available in the font, index returned points to '?'
    int index = rl::getGlyphIndex(font, codepoint);
    float scale = fontSize/(float)font.baseSize;

    // Character destination rectangle on screen
    // NOTE: We consider charsPadding on drawing
    position.x += (float)(font.glyphs[index].offsetX - font.glyphPadding)*scale;
    position.z += (float)(font.glyphs[index].offsetY - font.glyphPadding)*scale;

    // Character source rectangle from font texture atlas
    // NOTE: We consider chars padding when drawing, it could be required for outline/glow shader effects
    Rectangle srcRec = { font.recs[index].x - (float)font.glyphPadding, font.recs[index].y - (float)font.glyphPadding,
                         font.recs[index].width + 2.0f*font.glyphPadding, font.recs[index].height + 2.0f*font.glyphPadding };

    float width = (float)(font.recs[index].width + 2.0f*font.glyphPadding)*scale;
    float height = (float)(font.recs[index].height + 2.0f*font.glyphPadding)*scale;

    if (font.texture.id > 0)
    {
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;

        // normalized texture coordinates of the glyph inside the font texture (0.0f -> 1.0f)
        float tx = srcRec.x/font.texture.width;
        float ty = srcRec.y/font.texture.height;
        float tw = (srcRec.x+srcRec.width)/font.texture.width;
        float th = (srcRec.y+srcRec.height)/font.texture.height;

        if (SHOW_LETTER_BOUNDRY) {
            rl::drawCubeWiresV(
                { position.x + width/2, position.y, position.z + height/2},
                { width, LETTER_BOUNDRY_SIZE, height },
                LETTER_BOUNDRY_COLOR
            );
        }

        rlgl::rlCheckRenderBatchLimit(4 + (backface ? 4 : 0));
        rlgl::rlSetTexture(font.texture.id);

        rlgl::rlPushMatrix();
        rlgl::rlTranslatef(position.x, position.y, position.z);

            rlgl::rlBegin(rlgl::RL_QUADS);
                rlgl::rlColor4ub(tint.r, tint.g, tint.b, tint.a);

                // Front Face
                rlgl::rlNormal3f(0.0f, 1.0f, 0.0f);                                   // Normal Pointing Up
                rlgl::rlTexCoord2f(tx, ty); rlgl::rlVertex3f(x,         y, z);              // Top Left Of The Texture and Quad
                rlgl::rlTexCoord2f(tx, th); rlgl::rlVertex3f(x,         y, z + height);     // Bottom Left Of The Texture and Quad
                rlgl::rlTexCoord2f(tw, th); rlgl::rlVertex3f(x + width, y, z + height);     // Bottom Right Of The Texture and Quad
                rlgl::rlTexCoord2f(tw, ty); rlgl::rlVertex3f(x + width, y, z);              // Top Right Of The Texture and Quad

                if (backface) {
                    // Back Face
                    rlgl::rlNormal3f(0.0f, -1.0f, 0.0f);                                    // Normal Pointing Down
                    rlgl::rlTexCoord2f(tx, ty); rlgl::rlVertex3f(x,         y, z);          // Top Right Of The Texture and Quad
                    rlgl::rlTexCoord2f(tw, ty); rlgl::rlVertex3f(x + width, y, z);          // Top Left Of The Texture and Quad
                    rlgl::rlTexCoord2f(tw, th); rlgl::rlVertex3f(x + width, y, z + height); // Bottom Left Of The Texture and Quad
                    rlgl::rlTexCoord2f(tx, th); rlgl::rlVertex3f(x,         y, z + height); // Bottom Right Of The Texture and Quad
                }
            rlgl::rlEnd();
        rlgl::rlPopMatrix();

        rlgl::rlSetTexture(0);
    }
}

fn void draw_text_3d(
    Font font,
    String text,
    Vector3 position,
    float fontSize,
    float fontSpacing,
    float lineSpacing,
    bool backface,
    Color tint
) {
    float textOffsetY = 0.0f;               // Offset between lines (on line break '\n')
    float textOffsetX = 0.0f;               // Offset X to next character to draw

    float scale = fontSize/(float)font.baseSize;

    for (usz i = 0; i < text.len;) {
        // Get next codepoint from byte string and glyph index in font
        int codepointByteCount = 0;
        int codepoint = rl::getCodepoint((CChar *)&text[i], &codepointByteCount);
        int index = rl::getGlyphIndex(font, codepoint);

        // NOTE: Normally we exit the decoding sequence as soon as a bad byte is found (and return 0x3f)
        // but we need to draw all of the bad bytes using the '?' symbol moving one byte
        if (codepoint == 0x3f) codepointByteCount = 1;

        if (codepoint == '\n') {
            // NOTE: Fixed line spacing of 1.5 line-height
            // TODO: Support custom line spacing defined by user
            textOffsetY += fontSize + lineSpacing;
            textOffsetX = 0.0f;
        } else {
            if ((codepoint != ' ') && (codepoint != '\t')) {
                draw_text_codepoint_3d(font, codepoint, (Vector3){ position.x + textOffsetX, position.y, position.z + textOffsetY }, fontSize, backface, tint);
            }

            if (font.glyphs[index].advanceX == 0) {
                textOffsetX += (float)font.recs[index].width*scale + fontSpacing;
            } else {
                textOffsetX += (float)font.glyphs[index].advanceX*scale + fontSpacing;
            }
        }

        i += codepointByteCount;   // Move text bytes counter to next codepoint
    }
}

fn void draw_score_text(Vector3 position, ZString text) {
    Font font = rl::getFontDefault();

    Vector2 font_size = rl::measureTextEx(font, (CChar *)text, 1.6, 0.1);

    rlgl::rlPushMatrix();
        rlgl::rlTranslatef(position.x + 0.15, position.y + font_size.y/2, position.z + font_size.x/2);
        rlgl::rlRotatef(90.0f, 1.0f, 0.0f, 0.0f);
        rlgl::rlRotatef(90.0f, 0.0f, 0.0f, -1.0f);
        draw_text_3d(
            font,
            ((ZString)text).str_view(),
            { 0, 0, 0 },
            1.6,
            0.1,
            0.0,
            false,
            rl::BLACK,
        );
    rlgl::rlPopMatrix();
}

fn Vector3 Vector3.add(self, Vector3 other) @operator(+) => { self.x + other.x, self.y + other.y, self.z + other.z };
fn Vector3 Vector3.addf(self, float other) @operator(+) => { self.x + other, self.y + other, self.z + other };
fn Vector3 Vector3.sub(self, Vector3 other) @operator(-) => { self.x - other.x, self.y - other.y, self.z - other.z };
fn Vector3 Vector3.subf(self, float other) @operator(-) => { self.x - other, self.y - other, self.z - other };
fn Vector3 Vector3.div(self, float other) @operator(/) => { self.x / other, self.y / other, self.z / other };

fn int get_random() {
    if (rl::getRandomValue(1, 6) == 1) {
        return 0;
    }

    if (rl::getRandomValue(0, 1) == 1) {
        return rl::getRandomValue(-100, -1);
    } else {
        return rl::getRandomValue(1, 50);
    }
}

struct Side {
    int effect;
    bool collided;
}

fn Side new_side() {
    return (Side) {
        .effect = get_random(),
        .collided = false,
    };
}

fn Color Side.color(self) {
    if (self.collided) {
        return rl::RAYWHITE;
    }

    return self.effect < 0 ? rl::RED : rl::GREEN;
}

fn void Side.collide(&self, int* score) {
    if (self.collided) return;

    *score += self.effect;
    self.collided = true;
}

const Vector3 TARGET_SIZE = { 0.25, 3, 10 };

fn void Side.draw(&self, Vector3 center, BoundingBox player_box, int* score) {
    if (self.effect == 0) return;

    rl::drawCube(
        center,
        TARGET_SIZE.x, TARGET_SIZE.y, TARGET_SIZE.z,
        self.color(),
    );
    ZString s = (ZString)rl::textFormat("%+d", self.effect);
    draw_score_text(center, s);

    BoundingBox box = {
        .min = center - TARGET_SIZE/2,
        .max = center + TARGET_SIZE/2,
    };

    if (rl::checkCollisionBoxes(player_box, box)) {
        self.collide(score);
    }
}

struct Target {
    Vector3 pos;
    Side left;
    Side right;
}

fn void draw_score(int score) {
    int width = rl::getRenderWidth();
    int score_size = 45;
    CChar *score_text = rl::textFormat("%d", score);
    int score_width = rl::measureText(score_text, score_size);
    rl::drawText(score_text, width/2 - score_width/2, 10, score_size, rl::BLACK);
}

fn void main()
{
    rl::setConfigFlags(rl::FLAG_VSYNC_HINT | rl::FLAG_MSAA_4X_HINT);
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
            .left = new_side(),
            .right = new_side(),
        });
    }

    rl::setTargetFPS(60);
    int score = 10;
    while (!rl::windowShouldClose()) {
        // rl::updateCamera(&camera, rl::CAMERA_THIRD_PERSON);

        // Update the shader with the camera view vector (points towards { 0.0f, 0.0f, 0.0f })
        float[3] camera_pos = { camera.position.x, camera.position.y, camera.position.z };
        rl::setShaderValue(shader, shader.locs[rl::SHADER_LOC_VECTOR_VIEW], &camera_pos, rl::SHADER_UNIFORM_VEC3);

        update_light_values(shader, sun);

        float player_height = 2;
        rl::beginDrawing();
            rl::clearBackground(rl::SKYBLUE);

            Vector3 speed = { 0, 0, 0.2 };

            if (rl::isKeyDown(rl::KEY_LEFT)) {
                position += speed;
                float max = 10 - player_height/2;
                if (position.z > max) position.z = max;
            }
            if (rl::isKeyDown(rl::KEY_RIGHT)) {
                position -= speed;
                float min = -10 + player_height/2;
                if (position.z < min) position.z = min;
            }

            BoundingBox player_box = {
                .min = position - player_height/2,
                .max = position + player_height/2
            };
            rl::beginMode3D(camera); rl::beginShaderMode(shader);
                // platform
                rl::drawCube({ -125, 0, 0 }, 300, 0.5, 20, rl::RAYWHITE);

                rl::drawCube(
                    position + (Vector3){ 0, player_height/2, 0 },
                    player_height, player_height, player_height,
                    rl::RED,
                );

                foreach (&target : targets) {
                    Vector3 left_center = target.pos + TARGET_SIZE/2;
                    Vector3 right_center = target.pos + (Vector3){ TARGET_SIZE.x/2, TARGET_SIZE.y/2, -TARGET_SIZE.z/2 };

                    target.left.draw(left_center, player_box, &score);
                    target.right.draw(right_center, player_box, &score);

                    target.pos.x += 0.75;

                    if (target.pos.x > gap) {
                        target.pos.x = -(start + 9 * gap);
                        target.left = new_side();
                        target.right = new_side();
                    }
                }

            rl::endShaderMode(); rl::endMode3D();

            draw_score(score);
        rl::endDrawing();
    }

    rl::unloadShader(shader);
    rl::closeWindow();
}
