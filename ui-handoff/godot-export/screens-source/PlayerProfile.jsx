
function PlayerProfileScreen() {
  const [activeTab, setActiveTab] = React.useState("STATS");
  const tabs = ["STATS", "HISTORY", "ACHIEVEMENTS"];

  const stats = [
    { label: "HANDICAP", value: "+2.4", sub: "Scratch Golfer" },
    { label: "ROUNDS PLAYED", value: "47", sub: "18-hole rounds" },
    { label: "AVG SCORE", value: "71.2", sub: "vs Par 72" },
    { label: "BEST ROUND", value: "64", sub: "Cedar Valley · -8" },
    { label: "AVG PUTTS", value: "28.6", sub: "Per round" },
    { label: "FWY HIT %", value: "67%", sub: "Fairways in regulation" },
    { label: "GIR %", value: "74%", sub: "Greens in regulation" },
    { label: "EAGLES", value: "3", sub: "Career total" },
    { label: "BIRDIES", value: "188", sub: "Career total" },
    { label: "PARS", value: "621", sub: "Career total" },
    { label: "BOGEYS", value: "234", sub: "Career total" },
    { label: "DBL BOGEY+", value: "42", sub: "Career total" },
  ];

  const history = [
    { course: "Cedar Valley", date: "May 2, 2026", score: 68, par: 71, diff: -3 },
    { course: "Pineridge Links", date: "Apr 28, 2026", score: 74, par: 72, diff: +2 },
    { course: "Mesa Grande", date: "Apr 21, 2026", score: 70, par: 72, diff: -2 },
    { course: "Cedar Valley", date: "Apr 14, 2026", score: 69, par: 71, diff: -2 },
    { course: "Mesa Grande", date: "Apr 7, 2026", score: 73, par: 72, diff: +1 },
    { course: "Pineridge Links", date: "Mar 30, 2026", score: 76, par: 72, diff: +4 },
  ];

  const achievements = [
    { name: "ACE HUNTER", desc: "Score a hole-in-one", earned: true, date: "Mar 12" },
    { name: "EAGLE SCOUT", desc: "Record 3 career eagles", earned: true, date: "Apr 5" },
    { name: "SCRATCH FEVER", desc: "Reach scratch handicap", earned: true, date: "Feb 22" },
    { name: "UNDER PAR", desc: "Shoot under par 10 rounds", earned: true, date: "Jan 30" },
    { name: "FLAWLESS NINE", desc: "Play 9 holes without a bogey", earned: true, date: "Apr 28" },
    { name: "CONDOR", desc: "Score 4 under par on a single hole", earned: false },
    { name: "PERFECT ROUND", desc: "Shoot 18 pars or better", earned: false },
    { name: "LONG DRIVE", desc: "Hit a drive over 380 yards", earned: false },
    { name: "ALL COURSES", desc: "Complete all available courses", earned: false },
  ];

  // Bar chart for score distribution
  const distData = [
    { label: "EAGLE-", count: 3, color: "#d4af37" },
    { label: "BIRDIE", count: 188, color: "rgba(120,200,80,0.8)" },
    { label: "PAR", count: 621, color: "rgba(255,255,255,0.5)" },
    { label: "BOGEY", count: 234, color: "rgba(200,120,60,0.8)" },
    { label: "DBL+", count: 42, color: "rgba(180,60,60,0.8)" },
  ];
  const maxCount = Math.max(...distData.map(d => d.count));

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
        <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: 4 }}>PLAYER PROFILE</div>
      </div>

      <div style={{ display: "flex", height: "calc(100% - 58px)" }}>
        {/* Left — avatar + summary */}
        <div style={{
          width: 240, background: "rgba(0,0,0,0.4)",
          borderRight: "1px solid rgba(255,255,255,0.08)",
          display: "flex", flexDirection: "column", alignItems: "center",
          padding: "32px 24px", gap: 0
        }}>
          {/* Avatar placeholder */}
          <div style={{
            width: 100, height: 100, borderRadius: "50%",
            background: "rgba(255,255,255,0.06)",
            border: "2px solid rgba(120,200,80,0.4)",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 9, color: "rgba(255,255,255,0.2)", letterSpacing: 1, textAlign: "center"
          }}>
            AVATAR
          </div>
          <div style={{ marginTop: 16, fontSize: 20, fontWeight: 800, letterSpacing: 3, textAlign: "center" }}>PLAYER 1</div>
          <div style={{ fontSize: 11, letterSpacing: 2, color: "rgba(255,255,255,0.4)", marginTop: 4 }}>JOINED JAN 2026</div>

          {/* Handicap big badge */}
          <div style={{
            marginTop: 24, width: "100%",
            background: "rgba(80,140,60,0.2)", border: "1px solid rgba(120,200,80,0.35)",
            padding: "16px 0", textAlign: "center"
          }}>
            <div style={{ fontSize: 11, letterSpacing: 3, color: "rgba(255,255,255,0.5)", marginBottom: 4 }}>HANDICAP</div>
            <div style={{ fontSize: 40, fontWeight: 900, color: "rgba(120,200,80,0.95)", lineHeight: 1 }}>+2.4</div>
            <div style={{ fontSize: 10, letterSpacing: 2, color: "rgba(255,255,255,0.4)", marginTop: 4 }}>SCRATCH GOLFER</div>
          </div>

          {/* Quick stats */}
          <div style={{ marginTop: 20, width: "100%", display: "flex", flexDirection: "column", gap: 0 }}>
            {[
              ["ROUNDS", "47"],
              ["BEST", "64"],
              ["AVG", "71.2"],
            ].map(([l, v]) => (
              <div key={l} style={{
                display: "flex", justifyContent: "space-between",
                padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)"
              }}>
                <span style={{ fontSize: 12, letterSpacing: 2, color: "rgba(255,255,255,0.5)" }}>{l}</span>
                <span style={{ fontSize: 15, fontWeight: 700 }}>{v}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right — tabbed content */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
          {/* Tabs */}
          <div style={{
            display: "flex", gap: 0,
            borderBottom: "1px solid rgba(255,255,255,0.08)",
            background: "rgba(0,0,0,0.3)"
          }}>
            {tabs.map(t => (
              <div key={t} onClick={() => setActiveTab(t)} style={{
                padding: "14px 28px", fontSize: 14, fontWeight: 600, letterSpacing: 3,
                cursor: "pointer",
                color: activeTab === t ? "#fff" : "rgba(255,255,255,0.4)",
                borderBottom: activeTab === t ? "2px solid rgba(120,200,80,0.8)" : "2px solid transparent",
                transition: "all 0.1s"
              }}>{t}</div>
            ))}
          </div>

          {/* Tab content */}
          <div style={{ flex: 1, overflowY: "auto", padding: "24px 32px" }}>
            {activeTab === "STATS" && (
              <div>
                {/* Score distribution chart */}
                <div style={{ marginBottom: 32 }}>
                  <div style={{ fontSize: 11, letterSpacing: 3, color: "rgba(255,255,255,0.4)", marginBottom: 16 }}>SCORE DISTRIBUTION</div>
                  <div style={{ display: "flex", alignItems: "flex-end", gap: 12, height: 80 }}>
                    {distData.map(d => (
                      <div key={d.label} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6, flex: 1 }}>
                        <div style={{ fontSize: 11, color: "rgba(255,255,255,0.5)" }}>{d.count}</div>
                        <div style={{
                          width: "100%", background: d.color, borderRadius: "2px 2px 0 0",
                          height: `${(d.count / maxCount) * 56}px`, minHeight: 4, transition: "height 0.3s"
                        }}/>
                        <div style={{ fontSize: 9, letterSpacing: 1.5, color: "rgba(255,255,255,0.4)" }}>{d.label}</div>
                      </div>
                    ))}
                  </div>
                </div>
                {/* Stats grid */}
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 2 }}>
                  {stats.map(s => (
                    <div key={s.label} style={{
                      background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.06)",
                      padding: "14px 18px"
                    }}>
                      <div style={{ fontSize: 10, letterSpacing: 2, color: "rgba(255,255,255,0.4)", marginBottom: 4 }}>{s.label}</div>
                      <div style={{ fontSize: 24, fontWeight: 800 }}>{s.value}</div>
                      <div style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", marginTop: 2, letterSpacing: 1 }}>{s.sub}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {activeTab === "HISTORY" && (
              <div>
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
                  <thead>
                    <tr style={{ borderBottom: "1px solid rgba(255,255,255,0.1)" }}>
                      {["COURSE","DATE","SCORE","PAR","TO PAR"].map(h => (
                        <th key={h} style={{ padding: "8px 0", textAlign: "left", fontSize: 10, letterSpacing: 2.5, color: "rgba(255,255,255,0.4)", fontWeight: 600 }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {history.map((r, i) => (
                      <tr key={i} style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
                        <td style={{ padding: "14px 0", fontWeight: 600 }}>{r.course}</td>
                        <td style={{ padding: "14px 0", color: "rgba(255,255,255,0.5)", fontSize: 12, letterSpacing: 1 }}>{r.date}</td>
                        <td style={{ padding: "14px 0", fontWeight: 700, fontSize: 16 }}>{r.score}</td>
                        <td style={{ padding: "14px 0", color: "rgba(255,255,255,0.5)" }}>{r.par}</td>
                        <td style={{ padding: "14px 0" }}>
                          <span style={{
                            fontSize: 15, fontWeight: 800,
                            color: r.diff < 0 ? "rgba(120,200,80,0.9)" : r.diff > 0 ? "rgba(200,80,60,0.9)" : "#fff"
                          }}>{r.diff === 0 ? "E" : r.diff > 0 ? `+${r.diff}` : r.diff}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {activeTab === "ACHIEVEMENTS" && (
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
                {achievements.map(a => (
                  <div key={a.name} style={{
                    background: a.earned ? "rgba(80,140,60,0.15)" : "rgba(0,0,0,0.3)",
                    border: a.earned ? "1px solid rgba(120,200,80,0.3)" : "1px solid rgba(255,255,255,0.06)",
                    padding: "16px 18px",
                    opacity: a.earned ? 1 : 0.45
                  }}>
                    <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8, marginBottom: 6 }}>
                      <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: 2 }}>{a.name}</div>
                      {a.earned && <div style={{
                        width: 18, height: 18, borderRadius: "50%",
                        background: "rgba(120,200,80,0.25)",
                        border: "1px solid rgba(120,200,80,0.6)",
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontSize: 10, color: "rgba(120,200,80,0.9)", flexShrink: 0
                      }}>✓</div>}
                    </div>
                    <div style={{ fontSize: 11, color: "rgba(255,255,255,0.45)", letterSpacing: 1, lineHeight: 1.4 }}>{a.desc}</div>
                    {a.earned && <div style={{ fontSize: 10, color: "rgba(120,200,80,0.6)", marginTop: 8, letterSpacing: 1 }}>EARNED · {a.date}</div>}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { PlayerProfileScreen });
