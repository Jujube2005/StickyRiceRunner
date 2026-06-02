shader_type canvas_item;

uniform float curve_y : hint_range(-2.0, 2.0) = 0.4;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
    // เมื่ออยู่ใน SubViewport, SCREEN_UV จะเป็น 0.0 - 1.0 ของจอนั้นๆ เสมอ
    vec2 uv = SCREEN_UV;
    
    // คำนวณความห่างจากกึ่งกลางจอ (0.5)
    float dist_x = (uv.x - 0.5);
    
    // ดัดภาพให้โค้งลงที่ขอบจอ (Hill Effect)
    // การบวกค่าเข้าไปใน uv.y จะทำให้ Pixel นั้นดึงภาพจากตำแหน่งที่ "ต่ำกว่า" มาแสดง
    // ทำให้ขอบจอที่เคยเป็นเส้นขอบฟ้า ดูเหมือนตกลงไปข้างล่าง
    uv.y += (dist_x * dist_x) * curve_y;
    
    // ตรวจสอบขอบภาพเพื่อไม่ให้ดึงสีจากนอกจอมาปน
    if (uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.1, 0.1, 0.1, 1.0); // สีพื้นหลังมืดๆ นอกขอบโค้ง
    } else {
        COLOR = texture(screen_texture, uv);
    }
}
