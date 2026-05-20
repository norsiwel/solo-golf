
// In-Game HUD — Address Shot Screen
// Transparent background — overlays Godot 3D viewport
function HUDScreen() {
  const clubs = ["DRIVER","3 WOOD","5 WOOD","4 IRON","5 IRON","6 IRON","7 IRON","8 IRON","9 IRON","P WEDGE","S WEDGE","PUTTER"];
  const [selectedClub, setSelectedClub] = React.useState(0);
  const [power, setPower] = React.useState(2);
  const [spinX] = React.useState(0);
  const [spinY] = React.useState(0);

  // Shared chrome
  const navy = "rgba(20, 38, 64, 0.88)";
  const navyDeep = "rgba(14, 26, 46, 0.92)";
  const stroke = "rgba(255,255,255,0.22)";
  const radius = 8;

  return (
    <div style={{
      width: 1280, height: 800,
      position: "relative",
      fontFamily: "'Barlow Condensed', sans-serif",
      color: "#fff",
      background: "transparent",
      flexShrink: 0,
      overflow: "hidden"
    }}>

      {/* ───────── TOP LEFT — Hole Info ───────── */}
      <div style={{ position: "absolute", top: 18, left: 18, display: "flex", flexDirection: "column", gap: 6, width: 230 }}>
        {/* Hole + Par/Yds card */}
        <div style={{
          background: navy, border: `1px solid ${stroke}`, borderRadius: radius,
          overflow: "hidden"
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "8px 14px 6px", whiteSpace: "nowrap" }}>
            {/* Golfer silhouette */}
            <svg width="22" height="28" viewBox="0 0 22 28" fill="white">
              <circle cx="11" cy="3.5" r="2.4"/>
              <path d="M9 6 L13 6 L14.5 13 L17 19 L15.5 19.8 L13 14.5 L13 22 L15 27 L13 27 L11 22 L9 27 L7 27 L9 22 L9 14.5 L6.5 19.8 L5 19 L7.5 13 Z"/>
              <line x1="14" y1="9" x2="20" y2="6" stroke="white" strokeWidth="1.2"/>
            </svg>
            <span style={{ fontSize: 22, fontWeight: 700, letterSpacing: 1.5 }}>HOLE 7</span>
          </div>
          <div style={{ height: 1, background: "rgba(255,255,255,0.22)", margin: "0 12px" }}/>
          <div style={{ display: "flex", justifyContent: "space-between", padding: "6px 18px 8px", whiteSpace: "nowrap" }}>
            <span style={{ fontSize: 14, fontWeight: 600, letterSpacing: 1.5 }}>PAR 4</span>
            <span style={{ fontSize: 14, fontWeight: 600, letterSpacing: 1.5 }}>410 YDS</span>
          </div>
        </div>

        {/* Player card */}
        <div style={{
          background: navyDeep, border: `1px solid ${stroke}`, borderRadius: radius,
          padding: "8px 18px", display: "flex", justifyContent: "space-between", whiteSpace: "nowrap"
        }}>
          <span style={{ fontSize: 14, fontWeight: 600, letterSpacing: 1.5 }}>PLAYER 1</span>
          <span style={{ fontSize: 14, fontWeight: 700, letterSpacing: 1.5 }}>E</span>
        </div>
      </div>

      {/* ───────── TOP CENTER — Wind ───────── */}
      <div style={{
        position: "absolute", top: 22, left: "50%", transform: "translateX(-50%)",
        display: "flex", flexDirection: "column", alignItems: "center", gap: 2
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {/* Compass disc */}
          <div style={{
            width: 48, height: 48, borderRadius: "50%",
            border: "2px solid rgba(255,255,255,0.85)",
            display: "flex", alignItems: "center", justifyContent: "center",
            position: "relative"
          }}>
            <svg width="22" height="22" viewBox="0 0 22 22">
              {/* arrow pointing NW (-45°) */}
              <g transform="rotate(-45 11 11)">
                <path d="M11 2 L16 14 L11 11 L6 14 Z" fill="white"/>
              </g>
            </svg>
          </div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <span style={{ fontSize: 28, fontWeight: 700, lineHeight: 1, textShadow: "0 1px 3px rgba(0,0,0,0.6)" }}>12</span>
            <span style={{ fontSize: 13, fontWeight: 500, letterSpacing: 1.5, color: "rgba(255,255,255,0.85)", textShadow: "0 1px 3px rgba(0,0,0,0.6)" }}>MPH</span>
          </div>
        </div>
        <span style={{
          fontSize: 13, fontWeight: 600, letterSpacing: 2.5, marginTop: 4,
          textShadow: "0 1px 3px rgba(0,0,0,0.6)"
        }}>NW</span>
      </div>

      {/* ───────── TOP RIGHT — Spin Crosshair (transparent) ───────── */}
      <div style={{
        position: "absolute", top: 16, right: 24, width: 280, height: 280
      }}>
        <svg width="280" height="280" viewBox="0 0 280 280" style={{ filter: "drop-shadow(0 1px 3px rgba(0,0,0,0.5))" }}>
          {/* Outer ring */}
          <circle cx="140" cy="140" r="120" fill="none" stroke="white" strokeWidth="2"/>
          {/* Inner ring */}
          <circle cx="140" cy="140" r="60" fill="none" stroke="white" strokeWidth="2"/>
          {/* Cross axes */}
          <line x1="140" y1="20" x2="140" y2="260" stroke="white" strokeWidth="2"/>
          <line x1="20" y1="140" x2="260" y2="140" stroke="white" strokeWidth="2"/>
          {/* Tick dots — horizontal (5 per side, every 20px) */}
          {[40,60,80,100,120].map(x => (
            <circle key={"hl"+x} cx={140-x} cy="140" r="3.5" fill="white"/>
          ))}
          {[40,60,80,100,120].map(x => (
            <circle key={"hr"+x} cx={140+x} cy="140" r="3.5" fill="white"/>
          ))}
          {[40,60,80,100,120].map(y => (
            <circle key={"vt"+y} cx="140" cy={140-y} r="3.5" fill="white"/>
          ))}
          {[40,60,80,100,120].map(y => (
            <circle key={"vb"+y} cx="140" cy={140+y} r="3.5" fill="white"/>
          ))}
          {/* Labels */}
          <text x="140" y="14" fill="white" fontSize="13" fontWeight="600" fontFamily="'Barlow Condensed',sans-serif" letterSpacing="2" textAnchor="middle">LOFT</text>
          <text x="140" y="274" fill="white" fontSize="13" fontWeight="600" fontFamily="'Barlow Condensed',sans-serif" letterSpacing="2" textAnchor="middle">LOFT</text>
          <text x="14" y="144" fill="white" fontSize="13" fontWeight="600" fontFamily="'Barlow Condensed',sans-serif" letterSpacing="2" textAnchor="start">FADE</text>
          <text x="266" y="144" fill="white" fontSize="13" fontWeight="600" fontFamily="'Barlow Condensed',sans-serif" letterSpacing="2" textAnchor="end">DRAW</text>
          {/* Ball at center */}
          <circle cx={140 + spinX * 20} cy={140 - spinY * 20} r="11" fill="white"/>
          <circle cx={140 + spinX * 20 - 3} cy={140 - spinY * 20 - 3} r="2.5" fill="rgba(0,0,0,0.08)"/>
        </svg>
      </div>

      {/* ───────── RIGHT MIDDLE — Shot Power column ───────── */}
      <div style={{
        position: "absolute", top: 380, right: 220,
        display: "flex", flexDirection: "column", alignItems: "center"
      }}>
        <span style={{ fontSize: 12, letterSpacing: 2.5, fontWeight: 600, marginBottom: 8, textShadow: "0 1px 3px rgba(0,0,0,0.6)" }}>SHOT POWER</span>
        <div style={{
          background: navy, border: `1px solid ${stroke}`, borderRadius: radius,
          width: 96, overflow: "hidden"
        }}>
          {[{val:3,label:"FULL"},{val:2,label:"MEDIUM"},{val:1,label:"LOW"}].map((p, i) => (
            <React.Fragment key={p.val}>
              {i > 0 && <div style={{ height: 1, background: "rgba(255,255,255,0.18)", margin: "0 14px" }}/>}
              <div onClick={() => setPower(p.val)} style={{
                padding: "12px 0",
                display: "flex", flexDirection: "column", alignItems: "center",
                cursor: "pointer",
                background: p.val === power ? "rgba(255,255,255,0.08)" : "transparent"
              }}>
                <span style={{ fontSize: 28, fontWeight: 700, lineHeight: 1 }}>{p.val}</span>
                <span style={{ fontSize: 11, letterSpacing: 1.5, fontWeight: 600, marginTop: 3, color: "rgba(255,255,255,0.85)" }}>{p.label}</span>
              </div>
            </React.Fragment>
          ))}
        </div>
      </div>

      {/* ───────── RIGHT — Golf Bag (placeholder for real 3D asset) ───────── */}
      <div style={{
        position: "absolute", top: 380, right: 110, width: 110, height: 360,
        display: "flex", alignItems: "flex-end", justifyContent: "center"
      }}>
        <svg width="110" height="360" viewBox="0 0 110 360">
          {/* Clubs sticking out top */}
          <g stroke="#1a1a1a" strokeWidth="2" strokeLinecap="round">
            <line x1="35" y1="10" x2="40" y2="120"/>
            <line x1="45" y1="6" x2="48" y2="120"/>
            <line x1="55" y1="4" x2="55" y2="120"/>
            <line x1="65" y1="6" x2="62" y2="120"/>
            <line x1="75" y1="10" x2="70" y2="120"/>
            <line x1="42" y1="14" x2="44" y2="120" stroke="#444"/>
            <line x1="58" y1="8" x2="58" y2="120" stroke="#444"/>
            <line x1="68" y1="12" x2="66" y2="120" stroke="#444"/>
          </g>
          {/* Club heads */}
          <g fill="#cccccc" stroke="#555" strokeWidth="0.5">
            <ellipse cx="35" cy="10" rx="5" ry="3"/>
            <ellipse cx="45" cy="6" rx="5" ry="3"/>
            <ellipse cx="55" cy="4" rx="5" ry="3"/>
            <ellipse cx="65" cy="6" rx="5" ry="3"/>
            <ellipse cx="75" cy="10" rx="5" ry="3"/>
          </g>
          {/* Bag body */}
          <defs>
            <linearGradient id="bagGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0" stopColor="#2a2a2a"/>
              <stop offset="0.5" stopColor="#0a0a0a"/>
              <stop offset="1" stopColor="#2a2a2a"/>
            </linearGradient>
          </defs>
          {/* Bag top opening */}
          <ellipse cx="55" cy="120" rx="40" ry="10" fill="#0a0a0a" stroke="#c41e3a" strokeWidth="2"/>
          {/* Main bag body */}
          <path d="M 18 120 Q 15 200 20 280 L 22 340 Q 22 350 30 350 L 80 350 Q 88 350 88 340 L 90 280 Q 95 200 92 120 Z"
                fill="url(#bagGrad)" stroke="#c41e3a" strokeWidth="1.5"/>
          {/* White accent panel */}
          <path d="M 30 200 Q 28 260 32 320 L 78 320 Q 82 260 80 200 Z"
                fill="white" stroke="#c41e3a" strokeWidth="1.5"/>
          {/* Ball pocket circle */}
          <circle cx="55" cy="270" r="22" fill="white" stroke="#1a1a1a" strokeWidth="1.5"/>
          <circle cx="55" cy="270" r="18" fill="none" stroke="#1a1a1a" strokeWidth="0.5"/>
          {/* Red trim stripes */}
          <line x1="22" y1="200" x2="88" y2="200" stroke="#c41e3a" strokeWidth="2"/>
          <line x1="22" y1="320" x2="88" y2="320" stroke="#c41e3a" strokeWidth="1.5"/>
        </svg>
      </div>

      {/* ───────── FAR RIGHT — Club list ───────── */}
      <div style={{
        position: "absolute", top: 380, right: 18,
        display: "flex", flexDirection: "column", gap: 3
      }}>
        {clubs.map((c, i) => (
          <div key={c} onClick={() => setSelectedClub(i)} style={{
            padding: "5px 12px", width: 86,
            background: i === selectedClub ? "rgba(255,255,255,0.18)" : navy,
            border: `1px solid ${i === selectedClub ? "rgba(255,255,255,0.7)" : stroke}`,
            borderRadius: 6,
            fontSize: 11, fontWeight: 700, letterSpacing: 1.5, cursor: "pointer",
            color: "#fff",
            textAlign: "left",
            whiteSpace: "nowrap"
          }}>{c}</div>
        ))}
      </div>

      {/* ───────── BOTTOM LEFT — Lie info chip ───────── */}
      <div style={{
        position: "absolute", bottom: 80, left: 20,
        background: navyDeep, border: `1px solid ${stroke}`, borderRadius: radius,
        padding: "8px 18px", display: "flex", alignItems: "center", gap: 0
      }}>
        <div style={{ display: "flex", flexDirection: "column", paddingRight: 18 }}>
          <span style={{ fontSize: 9, letterSpacing: 2, fontWeight: 600, color: "rgba(255,255,255,0.6)" }}>TO PIN</span>
          <span style={{ fontSize: 18, fontWeight: 700, letterSpacing: 1, marginTop: 2 }}>410 YDS</span>
        </div>
        <div style={{ width: 1, height: 32, background: "rgba(255,255,255,0.25)" }}/>
        <div style={{ display: "flex", flexDirection: "column", padding: "0 18px" }}>
          <span style={{ fontSize: 9, letterSpacing: 2, fontWeight: 600, color: "rgba(255,255,255,0.6)" }}>ELEVATION</span>
          <span style={{ fontSize: 18, fontWeight: 700, letterSpacing: 1, marginTop: 2 }}>▲ 12 FT</span>
        </div>
        <div style={{ width: 1, height: 32, background: "rgba(255,255,255,0.25)" }}/>
        <div style={{ display: "flex", flexDirection: "column", paddingLeft: 18 }}>
          <span style={{ fontSize: 9, letterSpacing: 2, fontWeight: 600, color: "rgba(255,255,255,0.6)" }}>LIE</span>
          <span style={{ fontSize: 18, fontWeight: 700, letterSpacing: 1, marginTop: 2 }}>TEE</span>
        </div>
      </div>

      {/* ───────── BOTTOM — Swing meter (empty, separate rounded bar) ───────── */}
      <div style={{
        position: "absolute", bottom: 18, left: 20, right: 20,
        height: 36,
        background: "rgba(0,0,0,0.55)", border: `1px solid ${stroke}`, borderRadius: 18
      }}>
        {/* Power fill (subtle, for state preview) */}
        <div style={{
          position: "absolute", left: 4, top: 4, bottom: 4,
          width: `${(power / 3) * 50}%`,
          background: "linear-gradient(90deg, rgba(143,207,59,0.0), rgba(143,207,59,0.5))",
          borderRadius: 14
        }}/>
      </div>

    </div>
  );
}

Object.assign(window, { HUDScreen });
