// Экранный фон слоя Deep (см. ScaledSpaceLayer, FR-02). Квад висит перед
// MainCamera у дальней плоскости отсечения и показывает текстуру SubViewport'а
// слоя Deep через SCREEN_UV — поскольку DeepCamera каждый кадр копирует поворот
// и FOV основной камеры, прямая выборка по экранным координатам даёт точное
// попиксельное совпадение. Квад намеренно располагается у far-плоскости
// (см. BackgroundQuad в main.tscn) и не пишет глубину — обычный depth-тест
// сам решает, что рисовать поверх: любая реальная геометрия станции ближе
// камеры и всегда выигрывает сравнение глубины.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform sampler2D deep_texture : source_color, filter_linear;

void fragment() {
	ALBEDO = texture(deep_texture, SCREEN_UV).rgb;
}
