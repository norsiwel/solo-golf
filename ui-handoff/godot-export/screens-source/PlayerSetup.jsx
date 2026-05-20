
function PlayerSetupScreen() {
  const [name, setName] = React.useState("");
  const [gender, setGender] = React.useState("M"); // 'M' | 'F'
  const [hand, setHand] = React.useState("R"); // 'R' | 'L'
  const [focused, setFocused] = React.useState(false);

  // Tokens — matched to locker-room reference
  const panelGreen = "rgba(28, 56, 40, 0.88)";
  const cream = "#e8dfc7";
  const creamDim = "rgba(232, 223, 199, 0.55)";
  const creamSubtle = "rgba(232, 223, 199, 0.18)";
  const creamCard = "#d4cdb6";
  const creamCardDim = "#bbb39e";
  const accentLime = "#c8e070";
  const accentLimeGlow = "rgba(200, 224, 112, 0.45)";
  const darkText = "#2c3a2a";

  const canContinue = name.trim().length > 0;

  // Card component for gender/handedness
  const OptionCard = ({ active, onClick, icon, label, sub }) => (
    <div onClick={onClick} style={{
      flex: 1,
      background: active ? creamCard : creamCardDim,
      border: active ? `2px solid ${accentLime}` : `2px solid transparent`,
      borderRadius: 10,
      padding: "20px 16px 14px",
      cursor: "pointer",
      display: "flex", flexDirection: "column", alignItems: "center", gap: 10,
      boxShadow: active ? `0 0 0 1px ${accentLime}, 0 0 24px ${accentLimeGlow}` : "none",
      transition: "all 0.18s ease"
    }}>
      <div style={{
        color: active ? darkText : "rgba(80,90,80,0.55)",
        transition: "color 0.18s"
      }}>
        {icon}
      </div>
      <div style={{
        fontSize: 14, fontWeight: 700, letterSpacing: 2,
        color: active ? darkText : "rgba(80,90,80,0.7)",
        fontFamily: "'Inter', 'Helvetica Neue', sans-serif"
      }}>{label}</div>
      {sub && <div style={{
        fontSize: 10, letterSpacing: 1,
        color: active ? "rgba(44,58,42,0.7)" : "rgba(80,90,80,0.5)"
      }}>{sub}</div>}
    </div>
  );

  // Icons
  const MaleIcon = () => (
    <svg width="46" height="56" viewBox="0 0 46 56" fill="currentColor">
      <circle cx="23" cy="13" r="10"/>
      <path d="M8 56 C8 38, 16 28, 23 28 C30 28, 38 38, 38 56 Z"/>
    </svg>
  );
  const FemaleIcon = () => (
    <svg width="46" height="56" viewBox="0 0 46 56" fill="currentColor">
      <circle cx="23" cy="11" r="9"/>
      <path d="M14 56 L10 36 L18 32 L18 26 L28 26 L28 32 L36 36 L32 56 Z"/>
    </svg>
  );
  const GloveIcon = ({ flip = false }) => (
    <svg width="56" height="50" viewBox="0 0 56 50" fill="currentColor" style={{ transform: flip ? "scaleX(-1)" : "none" }}>
      {/* Glove silhouette */}
      <path d="M10 22 L10 14 Q10 10, 14 10 Q18 10, 18 14 L18 22 L20 22 L20 8 Q20 4, 24 4 Q28 4, 28 8 L28 22 L30 22 L30 6 Q30 2, 34 2 Q38 2, 38 6 L38 22 L40 22 L40 12 Q40 8, 44 8 Q48 8, 48 12 L48 28 Q48 42, 36 46 L18 46 Q10 44, 10 32 Z"/>
      {/* Club shaft going up-right */}
      <line x1="40" y1="10" x2="54" y2="0" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"/>
      {/* Club head */}
      <ellipse cx="53" cy="1" rx="3" ry="2" transform="rotate(-30 53 1)"/>
    </svg>
  );

  // Logo (flag + hill in circle, like the reference top-left)
  const Logo = () => (
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      <svg width="44" height="44" viewBox="0 0 44 44" fill="none">
        <circle cx="22" cy="22" r="20" stroke={cream} strokeWidth="1.5"/>
        {/* Hill */}
        <path d="M8 30 Q 16 22, 22 26 T 36 28 L 36 32 L 8 32 Z" fill={cream}/>
        {/* Flag pole */}
        <line x1="20" y1="10" x2="20" y2="28" stroke={cream} strokeWidth="1.5"/>
        {/* Flag */}
        <path d="M20 10 L28 13 L20 16 Z" fill={cream}/>
      </svg>
      <div style={{
        fontSize: 18, fontWeight: 700, letterSpacing: 2,
        color: cream, lineHeight: 1.1,
        fontFamily: "'Inter', 'Helvetica Neue', sans-serif"
      }}>
        OPEN WORLD<br/>GOLF
      </div>
    </div>
  );

  return (
    <div style={{
      width: 1280, height: 800, position: "relative", overflow: "hidden",
      fontFamily: "'Inter', 'Helvetica Neue', sans-serif",
      color: cream
    }}>
      {/* Locker room background */}
      <img src="assets/locker-room.png" alt=""
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "center" }}/>

      {/* Dark green left panel */}
      <div style={{
        position: "absolute", top: 0, bottom: 0, left: 0, width: 480,
        background: panelGreen,
        backdropFilter: "blur(2px)",
        padding: "36px 44px",
        display: "flex", flexDirection: "column", gap: 24,
        boxShadow: "8px 0 32px rgba(0,0,0,0.25)"
      }}>
        <Logo/>

        {/* Header */}
        <div>
          <div style={{
            fontSize: 26, fontWeight: 700, letterSpacing: 3,
            color: cream, marginBottom: 14
          }}>CREATE YOUR PLAYER</div>
          <div style={{ height: 1, background: creamSubtle }}/>
        </div>

        {/* Player Name */}
        <div>
          <div style={{
            fontSize: 12, fontWeight: 600, letterSpacing: 2,
            color: creamDim, marginBottom: 10
          }}>PLAYER NAME</div>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder="Enter your name"
            maxLength={20}
            style={{
              width: "100%", height: 50,
              background: "rgba(0,0,0,0.18)",
              border: `1.5px solid ${focused || name ? accentLime : creamDim}`,
              borderRadius: 6,
              padding: "0 18px",
              fontSize: 16,
              color: cream,
              fontFamily: "inherit",
              outline: "none",
              fontStyle: name ? "normal" : "italic",
              boxShadow: focused ? `0 0 0 1px ${accentLime}, 0 0 16px ${accentLimeGlow}` : "none",
              transition: "all 0.18s"
            }}
          />
        </div>

        {/* Gender */}
        <div>
          <div style={{
            fontSize: 12, fontWeight: 600, letterSpacing: 2,
            color: creamDim, marginBottom: 10
          }}>SELECT GENDER</div>
          <div style={{ display: "flex", gap: 10 }}>
            <OptionCard
              active={gender === "M"}
              onClick={() => setGender("M")}
              icon={<MaleIcon/>}
              label="MALE"
            />
            <OptionCard
              active={gender === "F"}
              onClick={() => setGender("F")}
              icon={<FemaleIcon/>}
              label="FEMALE"
            />
          </div>
        </div>

        {/* Handedness */}
        <div>
          <div style={{
            fontSize: 12, fontWeight: 600, letterSpacing: 2,
            color: creamDim, marginBottom: 10
          }}>SELECT HANDEDNESS</div>
          <div style={{ display: "flex", gap: 10 }}>
            <OptionCard
              active={hand === "R"}
              onClick={() => setHand("R")}
              icon={<GloveIcon flip={false}/>}
              label="RIGHT HANDED"
            />
            <OptionCard
              active={hand === "L"}
              onClick={() => setHand("L")}
              icon={<GloveIcon flip={true}/>}
              label="LEFT HANDED"
            />
          </div>
        </div>

        {/* Continue button */}
        <div style={{ marginTop: "auto" }}>
          <div style={{
            height: 56, borderRadius: 8,
            background: canContinue ? creamCard : "rgba(212, 205, 182, 0.4)",
            border: canContinue ? `1.5px solid ${accentLime}` : "1.5px solid rgba(232,223,199,0.25)",
            color: canContinue ? darkText : "rgba(44,58,42,0.4)",
            fontSize: 16, fontWeight: 700, letterSpacing: 4,
            display: "flex", alignItems: "center", justifyContent: "center",
            cursor: canContinue ? "pointer" : "not-allowed",
            boxShadow: canContinue ? `0 0 20px ${accentLimeGlow}` : "none",
            transition: "all 0.18s"
          }}>
            CONTINUE
          </div>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { PlayerSetupScreen });
