
function ScorecardScreen({ mode = "final", currentHole = 9, totalHoles = 18, autoAdvanceSec = 5 } = {}) {
  // mode: "between" (mid-round, timer + Hold/Continue) | "final" (end of round, static)
  // Up to 4 players. Solo = 1 entry. Each player has their own holes array.
  const players = [
    { name: "YOU", country: "🇺🇸", holes: [
      { hole: 1, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 2, par: 3, score: 2, putts: 1, fairway: null, gir: true },
      { hole: 3, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 4, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 5, par: 4, score: 3, putts: 1, fairway: true, gir: true },
      { hole: 6, par: 3, score: 3, putts: 2, fairway: null, gir: false },
      { hole: 7, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 8, par: 5, score: 4, putts: 1, fairway: true, gir: true },
      { hole: 9, par: 4, score: 5, putts: 3, fairway: false, gir: false },
      { hole: 10, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 11, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 12, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 13, par: 4, score: 3, putts: 1, fairway: true, gir: true },
      { hole: 14, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 15, par: 3, score: 2, putts: 1, fairway: null, gir: true },
      { hole: 16, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 17, par: 5, score: 6, putts: 3, fairway: false, gir: false },
      { hole: 18, par: 4, score: 4, putts: 2, fairway: true, gir: true },
    ]},
    { name: "MORGAN", country: "🇬🇧", holes: [
      { hole: 1, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 2, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 3, par: 5, score: 4, putts: 1, fairway: true, gir: true },
      { hole: 4, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 5, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 6, par: 3, score: 2, putts: 1, fairway: null, gir: true },
      { hole: 7, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 8, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 9, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 10, par: 4, score: 3, putts: 1, fairway: true, gir: true },
      { hole: 11, par: 3, score: 4, putts: 2, fairway: null, gir: false },
      { hole: 12, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 13, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 14, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 15, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 16, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 17, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 18, par: 4, score: 5, putts: 3, fairway: true, gir: true },
    ]},
    { name: "KENJI", country: "🇯🇵", holes: [
      { hole: 1, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 2, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 3, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 4, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 5, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 6, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 7, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 8, par: 5, score: 6, putts: 2, fairway: false, gir: false },
      { hole: 9, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 10, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 11, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 12, par: 5, score: 4, putts: 1, fairway: true, gir: true },
      { hole: 13, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 14, par: 4, score: 5, putts: 2, fairway: false, gir: false },
      { hole: 15, par: 3, score: 3, putts: 2, fairway: null, gir: true },
      { hole: 16, par: 4, score: 4, putts: 2, fairway: true, gir: true },
      { hole: 17, par: 5, score: 5, putts: 2, fairway: true, gir: true },
      { hole: 18, par: 4, score: 4, putts: 2, fairway: true, gir: true },
    ]},
  ]; // try slicing this to test 1, 2, or 3 players

  const [activeIdx, setActiveIdx] = React.useState(0);
  const player = players[activeIdx];
  const holes = player.holes;

  // Auto-advance timer (only in 'between' mode)
  const [held, setHeld] = React.useState(false);
  const [remaining, setRemaining] = React.useState(autoAdvanceSec);
  React.useEffect(() => { setRemaining(autoAdvanceSec); }, [autoAdvanceSec, mode]);
  React.useEffect(() => {
    if (mode !== "between" || held) return;
    if (remaining <= 0) return;
    const t = setInterval(() => setRemaining(r => Math.max(0, r - 0.1)), 100);
    return () => clearInterval(t);
  }, [mode, held, remaining]);
  const progressPct = mode === "between" ? (remaining / autoAdvanceSec) * 100 : 0;
  const isFinal = mode === "final";


  const totalPar = holes.reduce((s, h) => s + h.par, 0);
  const totalScore = holes.reduce((s, h) => s + h.score, 0);
  const toPar = totalScore - totalPar;
  const toParStr = toPar === 0 ? "E" : toPar > 0 ? `+${toPar}` : `${toPar}`;

  function scoreBg(score, par) {
    const d = score - par;
    if (d <= -2) return { bg: "#d4af37", border: "#d4af37", color: "#000" }; // eagle
    if (d === -1) return { bg: "rgba(120,200,80,0.3)", border: "rgba(120,200,80,0.8)", color: "#fff" }; // birdie circle
    if (d === 0) return { bg: "transparent", border: "rgba(255,255,255,0.2)", color: "#fff" };
    if (d === 1) return { bg: "rgba(200,80,60,0.25)", border: "rgba(200,80,60,0.7)", color: "#fff" }; // bogey
    return { bg: "rgba(180,40,40,0.35)", border: "rgba(180,40,40,0.9)", color: "#fff" }; // double+
  }

  const front = holes.slice(0, 9);
  const back = holes.slice(9);
  const frontPar = front.reduce((s,h) => s+h.par,0);
  const frontScore = front.reduce((s,h) => s+h.score,0);
  const backPar = back.reduce((s,h) => s+h.par,0);
  const backScore = back.reduce((s,h) => s+h.score,0);

  function HalfTable({ data, label }) {
    const sumPar = data.reduce((s,h)=>s+h.par,0);
    const sumScore = data.reduce((s,h)=>s+h.score,0);
    const sumPutts = data.reduce((s,h)=>s+h.putts,0);
    const fwHit = data.filter(h=>h.fairway===true).length;
    const fwAttempt = data.filter(h=>h.fairway!==null).length;
    const girHit = data.filter(h=>h.gir).length;
    return (
      <table style={{ borderCollapse:"collapse", width:"100%", fontSize:13 }}>
        <thead>
          <tr style={{ background:"rgba(0,0,0,0.5)" }}>
            <th style={th}>{label}</th>
            {data.map(h=>(
              <th key={h.hole} style={th}>{h.hole}</th>
            ))}
            <th style={{...th, background:"rgba(0,0,0,0.7)"}}>TOT</th>
          </tr>
        </thead>
        <tbody>
          <tr style={{ background:"rgba(0,0,0,0.3)" }}>
            <td style={td}>PAR</td>
            {data.map(h=><td key={h.hole} style={td}>{h.par}</td>)}
            <td style={{...td, fontWeight:700, background:"rgba(0,0,0,0.5)"}}>{sumPar}</td>
          </tr>
          <tr>
            <td style={td}>SCORE</td>
            {data.map(h=>{
              const s = scoreBg(h.score, h.par);
              return (
                <td key={h.hole} style={td}>
                  <div style={{
                    width:28, height:28, margin:"0 auto",
                    background:s.bg, border:`1.5px solid ${s.border}`,
                    borderRadius: (h.score-h.par)===-1?"50%":"2px",
                    display:"flex", alignItems:"center", justifyContent:"center",
                    fontSize:13, fontWeight:700, color:s.color
                  }}>{h.score}</div>
                </td>
              );
            })}
            <td style={{...td, fontWeight:800, fontSize:16, background:"rgba(0,0,0,0.5)"}}>
              {sumScore}
            </td>
          </tr>
          <tr style={{ background:"rgba(0,0,0,0.3)" }}>
            <td style={td}>PUTTS</td>
            {data.map(h=><td key={h.hole} style={{...td, color:"rgba(255,255,255,0.6)"}}>{h.putts}</td>)}
            <td style={{...td, background:"rgba(0,0,0,0.5)", color:"rgba(255,255,255,0.7)"}}>{sumPutts}</td>
          </tr>
          <tr>
            <td style={td}>FW</td>
            {data.map(h=>(
              <td key={h.hole} style={td}>
                {h.fairway===null
                  ? <span style={{color:"rgba(255,255,255,0.2)"}}>—</span>
                  : h.fairway
                    ? <span style={{color:"rgba(120,200,80,0.9)"}}>✓</span>
                    : <span style={{color:"rgba(200,80,60,0.9)"}}>✗</span>
                }
              </td>
            ))}
            <td style={{...td, background:"rgba(0,0,0,0.5)", color:"rgba(255,255,255,0.6)", fontSize:11}}>{fwHit}/{fwAttempt}</td>
          </tr>
          <tr style={{ background:"rgba(0,0,0,0.3)" }}>
            <td style={td}>GIR</td>
            {data.map(h=>(
              <td key={h.hole} style={td}>
                {h.gir
                  ? <span style={{color:"rgba(120,200,80,0.9)"}}>✓</span>
                  : <span style={{color:"rgba(200,80,60,0.9)"}}>✗</span>
                }
              </td>
            ))}
            <td style={{...td, background:"rgba(0,0,0,0.5)", color:"rgba(255,255,255,0.6)", fontSize:11}}>{girHit}/9</td>
          </tr>
        </tbody>
      </table>
    );
  }

  const th = {
    padding:"8px 0", textAlign:"center", letterSpacing:1.5,
    fontSize:10, fontWeight:600, color:"rgba(255,255,255,0.5)",
    borderBottom:"1px solid rgba(255,255,255,0.1)"
  };
  const td = {
    padding:"6px 0", textAlign:"center", fontSize:13,
    borderBottom:"1px solid rgba(255,255,255,0.06)"
  };

  return (
    <div style={{
      width:1280, height:800, position:"relative", overflow:"hidden",
      fontFamily:"'Barlow Condensed', sans-serif", color:"#fff",
      background:"linear-gradient(160deg, #0c1a0c 0%, #1a2e1a 60%, #0c1a0c 100%)"
    }}>
      {/* Header */}
      <div style={{
        background:"rgba(0,0,0,0.6)", borderBottom:"1px solid rgba(255,255,255,0.1)",
        display:"flex", alignItems:"center", justifyContent:"space-between",
        padding:"14px 28px"
      }}>
        <div style={{display:"flex",alignItems:"center",gap:20}}>
          <div style={{fontSize:13,letterSpacing:3,color:"rgba(255,255,255,0.4)",cursor:"pointer"}}>← MENU</div>
          <div style={{width:1,height:20,background:"rgba(255,255,255,0.15)"}}/>
          <div style={{fontSize:20,fontWeight:700,letterSpacing:4}}>{isFinal ? "FINAL SCORECARD" : `THROUGH HOLE ${currentHole} OF ${totalHoles}`}</div>
          <div style={{fontSize:13,letterSpacing:2,color:"rgba(255,255,255,0.4)"}}>CEDAR VALLEY · ROUND 1 · {players.length === 1 ? "SOLO" : `${players.length} PLAYERS`}</div>
        </div>
        {isFinal ? (
          <div style={{display:"flex",alignItems:"center",gap:12}}>
            <div style={{
              padding:"8px 20px",
              background:"rgba(80,160,60,0.2)", border:"1px solid rgba(120,200,80,0.4)",
              fontSize:13,fontWeight:600,letterSpacing:3,cursor:"pointer"
            }}>PLAY AGAIN</div>
            <div style={{
              padding:"8px 20px",
              background:"rgba(0,0,0,0.4)", border:"1px solid rgba(255,255,255,0.15)",
              fontSize:13,fontWeight:600,letterSpacing:3,cursor:"pointer"
            }}>MAIN MENU</div>
          </div>
        ) : (
          <div style={{ fontSize: 11, letterSpacing: 3, color: "rgba(255,255,255,0.45)" }}>
            CLICK ANY TAB TO REVIEW · AUTO-ADVANCE IN <span style={{ color: held ? "rgba(220,180,80,0.95)" : "rgba(160,210,120,0.95)", fontWeight: 700 }}>{held ? "HELD" : `${remaining.toFixed(1)}s`}</span>
          </div>
        )}
      </div>

      {/* Player tabs (hidden when solo) */}
      {players.length > 1 && (
        <div style={{
          display:"flex", background:"rgba(0,0,0,0.45)",
          borderBottom:"1px solid rgba(255,255,255,0.08)"
        }}>
          {players.map((p, i) => {
            const tot = p.holes.reduce((s,h)=>s+h.score,0);
            const par = p.holes.reduce((s,h)=>s+h.par,0);
            const tp = tot - par;
            const tpStr = tp === 0 ? "E" : tp > 0 ? `+${tp}` : `${tp}`;
            const active = i === activeIdx;
            return (
              <div key={i} onClick={() => setActiveIdx(i)} style={{
                flex: 1, padding: "12px 20px", cursor: "pointer",
                borderRight: i < players.length-1 ? "1px solid rgba(255,255,255,0.06)" : "none",
                borderBottom: active ? "2px solid rgba(120,200,80,0.9)" : "2px solid transparent",
                background: active ? "rgba(120,200,80,0.08)" : "transparent",
                display: "flex", alignItems: "center", gap: 14, transition: "all 0.15s"
              }}>
                <div style={{
                  fontSize: 11, letterSpacing: 2, fontWeight: 700,
                  width: 22, height: 22, borderRadius: 11,
                  background: active ? "rgba(120,200,80,0.85)" : "rgba(255,255,255,0.08)",
                  color: active ? "#0a120a" : "rgba(255,255,255,0.5)",
                  display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0
                }}>P{i+1}</div>
                <span style={{ fontSize: 18 }}>{p.country}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontSize: 14, fontWeight: 700, letterSpacing: 2,
                    color: active ? "#fff" : "rgba(255,255,255,0.55)",
                    overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap"
                  }}>{p.name}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: 1, color: active ? "#fff" : "rgba(255,255,255,0.6)" }}>{tot}</div>
                  <div style={{
                    fontSize: 10, fontWeight: 700, letterSpacing: 1,
                    color: tp < 0 ? "rgba(120,200,80,0.9)" : tp > 0 ? "rgba(200,80,60,0.9)" : "rgba(255,255,255,0.5)"
                  }}>{tpStr}</div>
                </div>
                {active && (
                  <div style={{
                    position: "relative", padding: "3px 8px",
                    background: "rgba(120,200,80,0.2)", border: "1px solid rgba(120,200,80,0.5)",
                    fontSize: 9, letterSpacing: 2, fontWeight: 700, color: "rgba(180,230,140,0.95)"
                  }}>TURN</div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <div style={{display:"flex",height: `calc(100% - 58px${players.length > 1 ? " - 50px" : ""}${!isFinal ? " - 64px" : ""})`}}>
        {/* Left — summary */}
        <div style={{
          width:200, flexShrink:0,
          background:"rgba(0,0,0,0.4)", borderRight:"1px solid rgba(255,255,255,0.08)",
          display:"flex",flexDirection:"column",gap:0,padding:"24px 0"
        }}>
          <div style={{padding:"0 24px 24px",borderBottom:"1px solid rgba(255,255,255,0.08)"}}>
            <div style={{fontSize:11,letterSpacing:3,color:"rgba(255,255,255,0.4)",marginBottom:6}}>{players.length === 1 ? "PLAYER" : `PLAYER ${activeIdx+1} OF ${players.length}`}</div>
            <div style={{fontSize:18, fontWeight:700, letterSpacing:3, color:"#fff", marginBottom:4}}>{player.name}</div>
            <div style={{fontSize:13,letterSpacing:2,color:"rgba(255,255,255,0.55)"}}>{player.country} CEDAR VALLEY</div>
          </div>
          {[
            ["TOTAL SCORE", totalScore],
            ["TO PAR", toParStr],
            ["FRONT 9", `${frontScore} (${frontScore-frontPar > 0 ? "+":""}${frontScore-frontPar === 0 ? "E" : frontScore-frontPar})`],
            ["BACK 9", `${backScore} (${backScore-backPar > 0 ? "+":""}${backScore-backPar === 0 ? "E" : backScore-backPar})`],
          ].map(([label, val]) => (
            <div key={label} style={{padding:"16px 24px",borderBottom:"1px solid rgba(255,255,255,0.06)"}}>
              <div style={{fontSize:10,letterSpacing:2,color:"rgba(255,255,255,0.4)",marginBottom:4}}>{label}</div>
              <div style={{
                fontSize: label==="TO PAR"?32:22, fontWeight:800,
                color: label==="TO PAR" ? (toPar < 0 ? "rgba(120,200,80,0.9)" : toPar > 0 ? "rgba(200,80,60,0.9)" : "#fff") : "#fff"
              }}>{val}</div>
            </div>
          ))}
          {/* Legend */}
          <div style={{padding:"16px 24px",marginTop:"auto"}}>
            <div style={{fontSize:10,letterSpacing:2,color:"rgba(255,255,255,0.3)",marginBottom:10}}>LEGEND</div>
            {[
              [{bg:"#d4af37",border:"#d4af37",radius:"2px",color:"#000"},"EAGLE"],
              [{bg:"rgba(120,200,80,0.3)",border:"rgba(120,200,80,0.8)",radius:"50%",color:"#fff"},"BIRDIE"],
              [{bg:"transparent",border:"rgba(255,255,255,0.3)",radius:"2px",color:"#fff"},"PAR"],
              [{bg:"rgba(200,80,60,0.25)",border:"rgba(200,80,60,0.7)",radius:"2px",color:"#fff"},"BOGEY"],
              [{bg:"rgba(180,40,40,0.35)",border:"rgba(180,40,40,0.9)",radius:"2px",color:"#fff"},"DBL+"],
            ].map(([s,label])=>(
              <div key={label} style={{display:"flex",alignItems:"center",gap:8,marginBottom:6}}>
                <div style={{width:18,height:18,background:s.bg,border:`1.5px solid ${s.border}`,borderRadius:s.radius,flexShrink:0}}/>
                <span style={{fontSize:10,letterSpacing:1.5,color:"rgba(255,255,255,0.5)"}}>{label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right — scorecard table */}
        <div style={{flex:1,padding:"24px 28px",overflowY:"auto"}}>
          <div style={{marginBottom:16}}>
            <HalfTable data={front} label="FRONT 9" />
          </div>
          <div>
            <HalfTable data={back} label="BACK 9" />
          </div>
        </div>
      </div>

      {/* Between-holes action bar with timer + HOLD / CONTINUE NOW */}
      {!isFinal && (
        <div style={{
          position:"absolute", bottom:0, left:0, right:0, height:64,
          background:"rgba(0,0,0,0.85)", borderTop:"1px solid rgba(255,255,255,0.1)",
          display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 28px"
        }}>
          {/* Progress bar */}
          <div style={{ position:"absolute", top:0, left:0, right:0, height:2, background:"rgba(255,255,255,0.05)" }}>
            <div style={{
              height:"100%", width:`${progressPct}%`,
              background: held ? "rgba(220,180,80,0.85)" : "rgba(120,200,80,0.85)",
              transition:"width 0.1s linear, background 0.2s",
              boxShadow: held ? "0 0 8px rgba(220,180,80,0.5)" : "0 0 8px rgba(120,200,80,0.5)"
            }}/>
          </div>

          <div style={{ fontSize:12, letterSpacing:3, color:"rgba(255,255,255,0.45)" }}>
            NEXT: {currentHole < totalHoles ? `HOLE ${currentHole + 1}` : "FINAL HOLE"}
            {players.length > 1 && " · NEXT PLAYER"}
          </div>

          <div style={{ display:"flex", gap:10 }}>
            <div onClick={() => setHeld(h => !h)} style={{
              padding:"10px 28px", fontSize:14, fontWeight:700, letterSpacing:3,
              background: held ? "rgba(220,180,80,0.25)" : "rgba(255,255,255,0.06)",
              border: `1px solid ${held ? "rgba(220,180,80,0.7)" : "rgba(255,255,255,0.15)"}`,
              color: held ? "rgba(245,210,120,0.95)" : "rgba(255,255,255,0.7)",
              cursor:"pointer", transition:"all 0.15s",
              display:"flex", alignItems:"center", gap:10
            }}>
              {held ? (
                <><svg width="10" height="12" viewBox="0 0 10 12" fill="currentColor"><polygon points="0,0 10,6 0,12"/></svg> RESUME</>
              ) : (
                <><svg width="10" height="12" viewBox="0 0 10 12" fill="currentColor"><rect x="0" y="0" width="3" height="12"/><rect x="7" y="0" width="3" height="12"/></svg> HOLD</>
              )}
            </div>
            <div onClick={() => setRemaining(0)} style={{
              padding:"10px 28px", fontSize:14, fontWeight:800, letterSpacing:3,
              background:"rgba(80,160,60,0.3)",
              border:"1px solid rgba(120,200,80,0.7)",
              color:"#fff", cursor:"pointer", transition:"all 0.15s",
              boxShadow:"0 0 16px rgba(120,200,80,0.25)"
            }}>CONTINUE NOW →</div>
          </div>
        </div>
      )}
    </div>
  );
}
Object.assign(window, { ScorecardScreen });
