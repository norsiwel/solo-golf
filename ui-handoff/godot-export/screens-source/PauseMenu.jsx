
function PauseMenuScreen() {
  const [hover, setHover] = React.useState(null);
  const items = [
    { label: "RESUME", sub: "Continue round" },
    { label: "OVERHEAD VIEW", sub: "See the full hole layout" },
    { label: "SETTINGS", sub: "Audio, display, controls" },
    { label: "RESTART HOLE", sub: "Replay from tee" },
    { label: "QUIT TO MENU", sub: "Progress will be saved" },
  ];

  return (
    <div style={{
      width: 1280, height: 800, position: "relative", overflow: "hidden",
      fontFamily: "'Barlow Condensed', sans-serif", color: "#fff",
      background: "transparent"
    }}>
      {/* Dark overlay — dims the live 3D scene in Godot */}
      <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.55)" }}/>

      {/* Centered panel */}
      <div style={{
        position: "absolute", top: "50%", left: "50%",
        transform: "translate(-50%, -50%)",
        width: 420,
        background: "rgba(8,18,8,0.92)",
        border: "1px solid rgba(255,255,255,0.12)",
        boxShadow: "0 0 60px rgba(0,0,0,0.8)"
      }}>
        {/* Panel header */}
        <div style={{
          padding: "22px 32px",
          borderBottom: "1px solid rgba(255,255,255,0.1)",
          display: "flex", alignItems: "center", justifyContent: "space-between"
        }}>
          <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: 5 }}>PAUSED</span>
          <div style={{ textAlign: "right" }}>
            <div style={{ fontSize: 11, letterSpacing: 2, color: "rgba(255,255,255,0.4)" }}>HOLE 7 · PAR 4</div>
            <div style={{ fontSize: 11, letterSpacing: 2, color: "rgba(255,255,255,0.4)" }}>STROKE 1 · 410 YDS</div>
          </div>
        </div>

        {/* Menu items */}
        <div style={{ padding: "12px 0" }}>
          {items.map((item, i) => (
            <div
              key={item.label}
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
              style={{
                padding: "14px 32px",
                cursor: "pointer",
                background: hover === i ? "rgba(80,140,60,0.18)" : "transparent",
                borderLeft: hover === i ? "3px solid rgba(120,200,80,0.7)" : "3px solid transparent",
                transition: "all 0.12s",
                display: "flex", alignItems: "center", justifyContent: "space-between"
              }}
            >
              <div>
                <div style={{
                  fontSize: i === 0 ? 20 : 16, fontWeight: 700, letterSpacing: 3,
                  color: i === 4 ? "rgba(200,80,60,0.8)" : "#fff"
                }}>{item.label}</div>
                <div style={{ fontSize: 11, letterSpacing: 1, color: "rgba(255,255,255,0.35)", marginTop: 2 }}>{item.sub}</div>
              </div>
              {hover === i && <span style={{ fontSize: 16, color: "rgba(120,200,80,0.7)" }}>→</span>}
            </div>
          ))}
        </div>

        {/* Bottom hint */}
        <div style={{
          padding: "12px 32px",
          borderTop: "1px solid rgba(255,255,255,0.08)",
          display: "flex", alignItems: "center", gap: 12
        }}>
          <div style={{
            padding: "3px 10px", border: "1px solid rgba(255,255,255,0.2)",
            background: "rgba(255,255,255,0.06)", fontSize: 11, fontWeight: 700,
            letterSpacing: 2
          }}>ESC</div>
          <span style={{ fontSize: 11, letterSpacing: 1.5, color: "rgba(255,255,255,0.35)" }}>TO RESUME</span>
        </div>
      </div>

      {/* Hole stats overlay — bottom right */}
      <div style={{
        position: "absolute", bottom: 28, right: 28,
        background: "rgba(0,0,0,0.7)", border: "1px solid rgba(255,255,255,0.1)",
        padding: "14px 20px"
      }}>
        <div style={{ fontSize: 10, letterSpacing: 3, color: "rgba(255,255,255,0.4)", marginBottom: 10 }}>THIS ROUND</div>
        {[["SCORE","E"],["HOLES PLAYED","6"],["PUTTS","13"],["FAIRWAYS","4/6"]].map(([l,v])=>(
          <div key={l} style={{ display:"flex", justifyContent:"space-between", gap:32, marginBottom:6 }}>
            <span style={{ fontSize:12, color:"rgba(255,255,255,0.5)", letterSpacing:1 }}>{l}</span>
            <span style={{ fontSize:12, fontWeight:700 }}>{v}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
Object.assign(window, { PauseMenuScreen });
