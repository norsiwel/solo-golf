
function SettingsScreen() {
  const [activeTab, setActiveTab] = React.useState("GAMEPLAY");
  const [vals, setVals] = React.useState({
    masterVol: 80, musicVol: 60, sfxVol: 90, ambientVol: 75,
    camSpeed: 65, fov: 70, motionBlur: true, vsync: true, dof: true,
    autoCamera: true, showTrajectory: true, gridOverlay: false,
    difficulty: "AMATEUR", units: "YARDS", handedness: "RIGHT",
    swingAssist: false, aimAssist: true, windIndicator: true,
    scorecardDuration: "STANDARD",
  });
  const set = (k, v) => setVals(p => ({ ...p, [k]: v }));

  const tabs = ["GAMEPLAY", "AUDIO", "DISPLAY", "CONTROLS"];

  const Slider = ({ label, k, min = 0, max = 100 }) => (
    <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
      <span style={{ flex: 1, fontSize: 14, letterSpacing: 1, color: "rgba(255,255,255,0.75)" }}>{label}</span>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ width: 180, height: 4, background: "rgba(255,255,255,0.12)", borderRadius: 2, position: "relative", cursor: "pointer" }}>
          <div style={{ width: `${((vals[k] - min) / (max - min)) * 100}%`, height: "100%", background: "rgba(120,200,80,0.8)", borderRadius: 2 }}/>
          <div style={{ position: "absolute", top: "50%", transform: "translateY(-50%)", left: `${((vals[k] - min) / (max - min)) * 100}%`, marginLeft: -6, width: 12, height: 12, background: "#fff", borderRadius: "50%", boxShadow: "0 0 6px rgba(0,0,0,0.5)" }}/>
        </div>
        <span style={{ fontSize: 14, fontWeight: 700, width: 32, textAlign: "right", color: "rgba(255,255,255,0.9)" }}>{vals[k]}</span>
      </div>
    </div>
  );

  const Toggle = ({ label, k, sub }) => (
    <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14, letterSpacing: 1, color: "rgba(255,255,255,0.75)" }}>{label}</div>
        {sub && <div style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", letterSpacing: 1, marginTop: 2 }}>{sub}</div>}
      </div>
      <div onClick={() => set(k, !vals[k])} style={{
        width: 44, height: 24, borderRadius: 12, cursor: "pointer",
        background: vals[k] ? "rgba(100,180,60,0.8)" : "rgba(255,255,255,0.15)",
        position: "relative", transition: "background 0.2s",
        border: vals[k] ? "1px solid rgba(120,200,80,0.6)" : "1px solid rgba(255,255,255,0.2)"
      }}>
        <div style={{
          position: "absolute", top: 3, left: vals[k] ? 22 : 3,
          width: 16, height: 16, borderRadius: "50%", background: "#fff",
          transition: "left 0.2s", boxShadow: "0 1px 4px rgba(0,0,0,0.4)"
        }}/>
      </div>
    </div>
  );

  const Radio = ({ label, k, options }) => (
    <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
      <span style={{ flex: 1, fontSize: 14, letterSpacing: 1, color: "rgba(255,255,255,0.75)" }}>{label}</span>
      <div style={{ display: "flex", gap: 3 }}>
        {options.map(o => (
          <div key={o} onClick={() => set(k, o)} style={{
            padding: "5px 14px", fontSize: 12, fontWeight: 600, letterSpacing: 1.5,
            cursor: "pointer",
            background: vals[k] === o ? "rgba(80,160,60,0.3)" : "rgba(255,255,255,0.06)",
            border: vals[k] === o ? "1px solid rgba(120,200,80,0.6)" : "1px solid rgba(255,255,255,0.12)",
            color: vals[k] === o ? "#fff" : "rgba(255,255,255,0.5)",
            transition: "all 0.1s"
          }}>{o}</div>
        ))}
      </div>
    </div>
  );

  const renderTab = () => {
    if (activeTab === "GAMEPLAY") return (
      <div>
        <Radio label="Difficulty" k="difficulty" options={["ROOKIE","AMATEUR","PRO","LEGEND"]}/>
        <Radio label="Distance Units" k="units" options={["YARDS","METERS"]}/>
        <Radio label="Handedness" k="handedness" options={["RIGHT","LEFT"]}/>
        <Toggle label="Swing Assist" k="swingAssist" sub="Highlights optimal swing timing window"/>
        <Toggle label="Aim Assist" k="aimAssist" sub="Subtle aim correction on drives"/>
        <Toggle label="Wind Indicator" k="windIndicator"/>
        <Toggle label="Show Trajectory" k="showTrajectory" sub="Preview shot arc before swinging"/>
        <Toggle label="Grid Overlay" k="gridOverlay" sub="Show aiming grid on green"/>
        <Radio label="Scorecard After Each Hole" k="scorecardDuration" options={["OFF","BRIEF","STANDARD","LONG","MANUAL"]}/>
      </div>
    );
    if (activeTab === "AUDIO") return (
      <div>
        <Slider label="Master Volume" k="masterVol"/>
        <Slider label="Music Volume" k="musicVol"/>
        <Slider label="SFX Volume" k="sfxVol"/>
        <Slider label="Ambient Volume" k="ambientVol"/>
      </div>
    );
    if (activeTab === "DISPLAY") return (
      <div>
        <Slider label="Camera Speed" k="camSpeed"/>
        <Slider label="Field of View" k="fov" min={60} max={110}/>
        <Toggle label="Motion Blur" k="motionBlur"/>
        <Toggle label="Depth of Field" k="dof" sub="Soft-focus distant background"/>
        <Toggle label="V-Sync" k="vsync"/>
        <Toggle label="Auto Camera" k="autoCamera" sub="Cinematic follow-cam after shots"/>
      </div>
    );
    if (activeTab === "CONTROLS") return (
      <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 13, letterSpacing: 1, paddingTop: 16 }}>
        {[
          ["SWING (HOLD + RELEASE)", "SPACE"],
          ["AIM LEFT / RIGHT", "A / D"],
          ["CYCLE CLUB UP / DOWN", "Q / E"],
          ["SHOT POWER CYCLE", "W / S"],
          ["SPIN ADJUST", "MOUSE"],
          ["CONFIRM", "ENTER"],
          ["PAUSE", "ESC"],
          ["OVERHEAD VIEW", "TAB"],
          ["CAMERA RESET", "R"],
        ].map(([action, key]) => (
          <div key={action} style={{
            display: "flex", justifyContent: "space-between", alignItems: "center",
            padding: "11px 0", borderBottom: "1px solid rgba(255,255,255,0.06)"
          }}>
            <span style={{ color: "rgba(255,255,255,0.7)" }}>{action}</span>
            <div style={{
              padding: "4px 14px", border: "1px solid rgba(255,255,255,0.2)",
              background: "rgba(255,255,255,0.06)", fontSize: 13, fontWeight: 700,
              letterSpacing: 2, color: "#fff", minWidth: 60, textAlign: "center"
            }}>{key}</div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div style={{
      width: 1280, height: 800, position: "relative", overflow: "hidden",
      fontFamily: "'Barlow Condensed', sans-serif", color: "#fff",
      background: "linear-gradient(160deg, #0c1a0c 0%, #1a2e1a 60%, #0c1a0c 100%)"
    }}>
      {/* Header */}
      <div style={{
        background: "rgba(0,0,0,0.6)", borderBottom: "1px solid rgba(255,255,255,0.1)",
        display: "flex", alignItems: "center", gap: 20, padding: "14px 28px"
      }}>
        <div style={{ fontSize: 13, letterSpacing: 3, color: "rgba(255,255,255,0.4)", cursor: "pointer" }}>← BACK</div>
        <div style={{ width: 1, height: 20, background: "rgba(255,255,255,0.15)" }}/>
        <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: 4 }}>SETTINGS</div>
      </div>

      <div style={{ display: "flex", height: "calc(100% - 58px)" }}>
        {/* Left tabs */}
        <div style={{
          width: 200, background: "rgba(0,0,0,0.4)",
          borderRight: "1px solid rgba(255,255,255,0.08)",
          display: "flex", flexDirection: "column", padding: "24px 0"
        }}>
          {tabs.map(t => (
            <div key={t} onClick={() => setActiveTab(t)} style={{
              padding: "14px 28px", fontSize: 15, fontWeight: 600, letterSpacing: 3,
              cursor: "pointer",
              color: activeTab === t ? "#fff" : "rgba(255,255,255,0.4)",
              background: activeTab === t ? "rgba(80,140,60,0.2)" : "transparent",
              borderLeft: activeTab === t ? "3px solid rgba(120,200,80,0.8)" : "3px solid transparent",
              transition: "all 0.1s"
            }}>{t}</div>
          ))}
          <div style={{ flex: 1 }}/>
          <div style={{ padding: "0 20px" }}>
            <div style={{
              padding: "10px 0", textAlign: "center",
              border: "1px solid rgba(200,80,60,0.35)",
              background: "rgba(200,80,60,0.1)",
              fontSize: 13, fontWeight: 600, letterSpacing: 2,
              color: "rgba(200,80,60,0.8)", cursor: "pointer"
            }}>RESET DEFAULTS</div>
          </div>
        </div>

        {/* Right content */}
        <div style={{ flex: 1, padding: "28px 40px", overflowY: "auto" }}>
          <div style={{ fontSize: 13, letterSpacing: 3, color: "rgba(255,255,255,0.3)", marginBottom: 20 }}>{activeTab}</div>
          {renderTab()}
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { SettingsScreen });
