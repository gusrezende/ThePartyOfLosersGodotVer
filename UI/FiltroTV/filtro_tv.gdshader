shader_type canvas_item;
// FILTRO DE TV DE TUBO (CRT). Cada efeito tem um controle; 0 desliga aquele efeito.

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;

uniform float curvatura : hint_range(0.0, 0.3) = 0.06;         // tela "abaulada"
uniform float linhas_intensidade : hint_range(0.0, 1.0) = 0.22; // linhas de varredura
uniform float linhas_quantidade = 240.0;                        // quantas linhas na tela
uniform float aberracao : hint_range(0.0, 4.0) = 1.2;           // cores "vazando" (vermelho/azul separados)
uniform float vinheta : hint_range(0.0, 1.0) = 0.35;            // bordas mais escuras
uniform float mascara_rgb : hint_range(0.0, 0.5) = 0.08;        // grade de fósforo R G B
uniform float tremulacao : hint_range(0.0, 0.2) = 0.025;        // brilho piscando de leve
uniform float ruido : hint_range(0.0, 0.3) = 0.035;             // chiado
uniform float faixa_rolando : hint_range(0.0, 0.3) = 0.04;      // faixa clara que desce devagar
uniform float brilho : hint_range(0.5, 2.0) = 1.12;             // compensa o escurecimento das linhas
uniform float borda_arredondada : hint_range(0.0, 0.2) = 0.04;  // cantos arredondados da tela

float aleatorio(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curvar(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	uv += uv * (uv.yx * uv.yx) * curvatura;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curvar(SCREEN_UV);

	// fora da tela de vidro: preto (com cantos arredondados)
	vec2 dentro = abs(uv - 0.5) * 2.0;
	vec2 canto = max(dentro - (1.0 - borda_arredondada), 0.0) / max(borda_arredondada, 0.0001);
	float fora = step(1.0, length(canto)) + step(1.0, max(dentro.x, dentro.y));
	if (fora > 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// cores separadas: mais forte perto das bordas
		vec2 px = SCREEN_PIXEL_SIZE * aberracao * (0.4 + length(uv - 0.5));
		vec3 cor;
		cor.r = texture(tela, uv + vec2(px.x, 0.0)).r;
		cor.g = texture(tela, uv).g;
		cor.b = texture(tela, uv - vec2(px.x, 0.0)).b;

		// linhas de varredura
		float linha = 0.5 + 0.5 * sin(uv.y * linhas_quantidade * 6.28318);
		cor *= 1.0 - linhas_intensidade * linha;

		// grade de fósforo (colunas R, G, B)
		int coluna = int(mod(FRAGCOORD.x, 3.0));
		vec3 mascara = vec3(1.0 - mascara_rgb);
		if (coluna == 0) mascara.r = 1.0;
		else if (coluna == 1) mascara.g = 1.0;
		else mascara.b = 1.0;
		cor *= mascara;

		// faixa clara que desce devagar, como TV antiga
		float faixa = smoothstep(0.0, 0.08, 0.08 - abs(fract(uv.y - TIME * 0.08) - 0.5) * 0.25);
		cor += faixa * faixa_rolando;

		// bordas escuras
		vec2 v = uv * (1.0 - uv.yx);
		cor *= mix(1.0, pow(v.x * v.y * 15.0, 0.3), vinheta);

		// tremulação e chiado
		cor *= 1.0 - tremulacao * (0.5 + 0.5 * sin(TIME * 60.0));
		cor += (aleatorio(uv * vec2(TIME * 0.37 + 1.0, TIME * 0.71 + 2.0)) - 0.5) * ruido;

		COLOR = vec4(cor * brilho, 1.0);
	}
}
