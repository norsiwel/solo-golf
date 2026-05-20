
function MainMenuScreen() {
  const [hover, setHover] = React.useState(null);
  const menuItems = ["PLAY", "COURSE SELECT", "PLAYER PROFILE", "SETTINGS", "QUIT"];

  return (
    <div style={{
      width: 1280, height: 800, position: "relative", overflow: "hidden",
      fontFamily: "'Barlow Condensed', sans-serif", color: "#fff",
      background: "#0a120a"
    }}>
      {/* Title image background — fills the whole screen */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: "url('assets/title-bg.png')",
        backgroundSize: "cover",
        backgroundPosition: "center"
      }}/>
      {/* Subtle bottom darkening so menu items remain legible */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0, height: 220,
        background: "linear-gradient(180deg, transparent 0%, rgba(5,14,5,0.55) 60%, rgba(5,14,5,0.92) 100%)"
      }}/>

      {/* Thin top bar */}
      <div style={{
        position: "absolute", top: 0, left: 0, right: 0, height: 3,
        background: "linear-gradient(90deg, transparent, rgba(120,200,80,0.6), transparent)"
      }}/>

      {/* Logo / Title — hidden because the title art already includes the logo */}
      <div style={{ display: "none" }}>
        {/* Golf flag icon */}
        <svg width="48" height="52" viewBox="0 0 48 52" fill="none">
          <rect x="22" y="4" width="2" height="38" fill="rgba(255,255,255,0.9)"/>
          <polygon points="24,4 24,22 40,13" fill="rgba(120,200,80,0.9)"/>
          <ellipse cx="22" cy="44" rx="12" ry="3" fill="rgba(255,255,255,0.15)"/>
        </svg>
        <div style={{
          fontSize: 64, fontWeight: 800, letterSpacing: 10,
          textTransform: "uppercase",
          background: "linear-gradient(180deg, #ffffff 0%, rgba(180,220,140,0.8) 100%)",
          WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent",
          lineHeight: 1
        }}>OPEN WORLD GOLF</div>
        <div style={{
          fontSize: 16, fontWeight: 400, letterSpacing: 8,
          color: "rgba(160,210,120,0.7)", textTransform: "uppercase"
        }}>WALK THE WALK</div>
      </div>

      {/* Menu Items — horizontal pill row at bottom, doesn't clash with the artwork */}
      <div style={{
        position: "absolute", bottom: 70, left: 0, right: 0,
        display: "flex", justifyContent: "center", gap: 14
      }}>
        {menuItems.map((item, i) => {
          const isPrimary = i === 0;
          const isHovered = hover === i;
          return (
            <div
              key={item}
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
              style={{
                padding: isPrimary ? "14px 36px" : "12px 28px",
                cursor: "pointer",
                background: isPrimary
                  ? (isHovered ? "rgba(28, 56, 40, 0.95)" : "rgba(28, 56, 40, 0.85)")
                  : (isHovered ? "rgba(0,0,0,0.55)" : "rgba(0,0,0,0.4)"),
                border: isPrimary
                  ? `1.5px solid ${isHovered ? "#c8e070" : "rgba(232, 223, 199, 0.6)"}`
                  : `1px solid ${isHovered ? "rgba(232, 223, 199, 0.65)" : "rgba(232, 223, 199, 0.25)"}`,
                borderRadius: 8,
                backdropFilter: "blur(6px)",
                fontSize: isPrimary ? 16 : 13,
                fontWeight: 700,
                letterSpacing: 4,
                color: isPrimary ? "#e8dfc7" : (isHovered ? "#e8dfc7" : "rgba(232, 223, 199, 0.7)"),
                fontFamily: "'Inter', 'Helvetica Neue', sans-serif",
                boxShadow: isPrimary && isHovered ? "0 0 24px rgba(200, 224, 112, 0.35)" : "none",
                transition: "all 0.18s ease"
              }}
            >{item}</div>
          );
        })}
      </div>

      {/* Footer */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "14px 28px"
      }}>
        <span style={{ fontSize: 11, letterSpacing: 2, color: "rgba(232,223,199,0.45)", fontFamily: "'Inter', sans-serif" }}>VERSION 1.0.0</span>
        <span style={{ fontSize: 11, letterSpacing: 2, color: "rgba(232,223,199,0.45)", fontFamily: "'Inter', sans-serif" }}>© 2026 OPEN WORLD GOLF</span>
      </div>
    </div>
  );
}
Object.assign(window, { MainMenuScreen });
