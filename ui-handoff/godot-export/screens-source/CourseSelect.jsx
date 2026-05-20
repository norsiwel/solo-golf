
function CourseSelectScreen() {
  // Placeholder courses — in Godot these come from the courses folder.
  // The cards in this mockup are intentionally blank/title-only.
  const allCourses = [
    { id: 0, name: "PINERIDGE LINKS", location: "SCOTLAND" },
    { id: 1, name: "CEDAR VALLEY", location: "APPALACHIANS, USA" },
    { id: 2, name: "MESA GRANDE", location: "ARIZONA, USA" },
    { id: 3, name: "SHIRAKAWA", location: "KYOTO, JAPAN" },
    { id: 4, name: "DUNMARA BAY", location: "IRELAND" },
    { id: 5, name: "PEBBLE POINT", location: "CALIFORNIA, USA" },
    { id: 6, name: "ROYAL ASHWICK", location: "ENGLAND" },
    { id: 7, name: "KAUAI SHORES", location: "HAWAII, USA" },
  ];

  // Tokens — match locker-room aesthetic
  const panelGreen = "rgba(28, 56, 40, 0.92)";
  const cream = "#e8dfc7";
  const creamDim = "rgba(232, 223, 199, 0.55)";
  const creamSubtle = "rgba(232, 223, 199, 0.18)";
  const accentLime = "#c8e070";
  const accentLimeGlow = "rgba(200, 224, 112, 0.45)";
  const cardCream = "#d4cdb6";
  const darkText = "#2c3a2a";

  const [query, setQuery] = React.useState("");
  const [holes, setHoles] = React.useState(18);
  const [current, setCurrent] = React.useState(0);
  const [animDir, setAnimDir] = React.useState(null);

  const filtered = query.trim()
    ? allCourses.filter(c =>
        c.name.toLowerCase().includes(query.toLowerCase()) ||
        c.location.toLowerCase().includes(query.toLowerCase()))
    : allCourses;

  // Clamp current to filtered range
  React.useEffect(() => { setCurrent(0); }, [query]);
  const c = filtered.length ? filtered[Math.min(current, filtered.length - 1)] : null;

  const navigate = (dir) => {
    if (filtered.length < 2) return;
    setAnimDir(dir);
    setTimeout(() => {
      setCurrent(i => (i + (dir === 'right' ? 1 : -1) + filtered.length) % filtered.length);
      setAnimDir(null);
    }, 180);
  };
  const randomCourse = () => {
    if (filtered.length < 1) return;
    setAnimDir('right');
    setTimeout(() => {
      setCurrent(Math.floor(Math.random() * filtered.length));
      setAnimDir(null);
    }, 180);
  };

  const slideStyle = {
    transition: animDir ? "opacity 0.18s ease, transform 0.18s ease" : "none",
    opacity: animDir ? 0 : 1,
    transform: animDir === 'left' ? "translateX(40px)" : animDir === 'right' ? "translateX(-40px)" : "translateX(0)"
  };

  return (
    <div style={{
      width: 1280, height: 800, position: "relative", overflow: "hidden",
      fontFamily: "'Inter', 'Helvetica Neue', sans-serif", color: cream,
      background: "#0d1f17",
      backgroundImage: "linear-gradient(160deg, #0d1f17 0%, #1a2e22 50%, #0d1f17 100%)"
    }}>

      {/* Header */}
      <div style={{
        background: panelGreen, borderBottom: `1px solid ${creamSubtle}`,
        display:"flex", alignItems:"center", gap:24, padding:"16px 32px"
      }}>
        <div style={{ fontSize: 12, letterSpacing: 3, color: creamDim, cursor: "pointer", fontWeight: 600 }}>← BACK</div>
        <div style={{ width: 1, height: 20, background: creamSubtle }}/>
        <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: 4, color: cream }}>COURSE SELECT</div>
        <div style={{ flex: 1 }}/>
        <div style={{ fontSize: 11, letterSpacing: 2, color: creamDim, fontWeight: 600 }}>
          {filtered.length} OF {allCourses.length} COURSES
        </div>
      </div>

      {/* Search bar */}
      <div style={{ padding: "20px 32px 0", display: "flex", gap: 12, alignItems: "center" }}>
        <div style={{
          flex: 1, position: "relative",
          background: "rgba(0,0,0,0.25)", border: `1.5px solid ${query ? accentLime : creamSubtle}`,
          borderRadius: 8, height: 46,
          display: "flex", alignItems: "center", padding: "0 16px", gap: 12,
          boxShadow: query ? `0 0 0 1px ${accentLime}, 0 0 16px ${accentLimeGlow}` : "none",
          transition: "all 0.18s"
        }}>
          {/* Search icon */}
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <circle cx="8" cy="8" r="6" stroke={creamDim} strokeWidth="1.8"/>
            <line x1="12.5" y1="12.5" x2="16" y2="16" stroke={creamDim} strokeWidth="1.8" strokeLinecap="round"/>
          </svg>
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search courses by name or location"
            style={{
              flex: 1, height: "100%",
              background: "transparent", border: "none", outline: "none",
              fontFamily: "inherit", fontSize: 15, letterSpacing: 1,
              color: cream
            }}
          />
          {query && (
            <div onClick={() => setQuery("")} style={{
              cursor: "pointer", padding: "4px 8px", borderRadius: 4,
              fontSize: 11, letterSpacing: 1.5, color: creamDim, fontWeight: 600
            }}>CLEAR ✕</div>
          )}
        </div>
      </div>

      {/* Carousel area */}
      <div style={{
        position: "absolute", top: 138, bottom: 110, left: 0, right: 0,
        display: "flex", alignItems: "center", gap: 0, padding: "0 24px"
      }}>
        {/* Left arrow */}
        <div onClick={() => navigate('left')} style={{
          width: 56, height: 56, flexShrink: 0,
          background: panelGreen, border: `1px solid ${creamSubtle}`,
          borderRadius: 28, cursor: filtered.length > 1 ? "pointer" : "default",
          display: "flex", alignItems: "center", justifyContent: "center",
          opacity: filtered.length > 1 ? 1 : 0.35, transition: "all 0.15s"
        }}>
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <polyline points="13,4 6,10 13,16" stroke={cream} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>

        {/* Title card */}
        <div style={{ flex: 1, height: "100%", padding: "0 24px", display: "flex", flexDirection: "column", justifyContent: "center", ...slideStyle }}>
          {c ? (
            <div style={{
              flex: 1, background: panelGreen, border: `1.5px solid ${creamSubtle}`,
              borderRadius: 12, position: "relative", overflow: "hidden",
              display: "flex", flexDirection: "column",
              boxShadow: "0 16px 48px rgba(0,0,0,0.4)"
            }}>
              {/* Image placeholder — populated by course folder */}
              <div style={{
                flex: 1, position: "relative",
                background: `repeating-linear-gradient(45deg, rgba(232,223,199,0.04) 0 12px, rgba(232,223,199,0.02) 12px 24px)`,
                display: "flex", alignItems: "center", justifyContent: "center",
                borderBottom: `1px solid ${creamSubtle}`
              }}>
                <div style={{
                  textAlign: "center", color: "rgba(232,223,199,0.18)",
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 10
                }}>
                  <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
                    <rect x="6" y="30" width="48" height="22" rx="2" fill="rgba(232,223,199,0.1)" stroke="rgba(232,223,199,0.25)" strokeWidth="1"/>
                    <ellipse cx="30" cy="20" rx="18" ry="12" fill="rgba(232,223,199,0.06)" stroke="rgba(232,223,199,0.2)" strokeWidth="1"/>
                    <circle cx="30" cy="20" r="4" fill="rgba(232,223,199,0.2)"/>
                    <line x1="30" y1="16" x2="30" y2="10" stroke="rgba(232,223,199,0.3)" strokeWidth="1.5"/>
                    <polygon points="30,10 30,14 34,12" fill="rgba(200,224,112,0.5)"/>
                  </svg>
                  <span style={{ fontSize: 10, letterSpacing: 2.5, fontWeight: 600 }}>COURSE THUMBNAIL</span>
                  <span style={{ fontSize: 9, letterSpacing: 2, opacity: 0.5 }}>POPULATED FROM /COURSES</span>
                </div>
              </div>
              {/* Title bar */}
              <div style={{
                padding: "20px 28px",
                background: "rgba(0,0,0,0.4)",
                display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16
              }}>
                <div>
                  <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: 4, color: cream, lineHeight: 1.1 }}>{c.name}</div>
                  <div style={{ fontSize: 13, letterSpacing: 3, color: creamDim, marginTop: 4 }}>{c.location}</div>
                </div>
                <div style={{ fontSize: 11, letterSpacing: 2.5, color: creamDim, fontWeight: 600 }}>
                  {current + 1} / {filtered.length}
                </div>
              </div>
            </div>
          ) : (
            <div style={{
              flex: 1, background: panelGreen, border: `1.5px solid ${creamSubtle}`,
              borderRadius: 12, display: "flex", flexDirection: "column",
              alignItems: "center", justifyContent: "center", gap: 12
            }}>
              <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: 3, color: creamDim }}>NO COURSES FOUND</div>
              <div style={{ fontSize: 13, letterSpacing: 2, color: "rgba(232,223,199,0.35)" }}>Try a different search</div>
            </div>
          )}
        </div>

        {/* Right arrow */}
        <div onClick={() => navigate('right')} style={{
          width: 56, height: 56, flexShrink: 0,
          background: panelGreen, border: `1px solid ${creamSubtle}`,
          borderRadius: 28, cursor: filtered.length > 1 ? "pointer" : "default",
          display: "flex", alignItems: "center", justifyContent: "center",
          opacity: filtered.length > 1 ? 1 : 0.35, transition: "all 0.15s"
        }}>
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <polyline points="7,4 14,10 7,16" stroke={cream} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      </div>

      {/* Bottom action bar */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0, height: 90,
        background: panelGreen, borderTop: `1px solid ${creamSubtle}`,
        display: "flex", alignItems: "center", justifyContent: "center", gap: 12,
        padding: "0 32px"
      }}>
        {/* Holes toggle */}
        {[9, 18].map(h => (
          <div key={h} onClick={() => setHoles(h)} style={{
            padding: "14px 28px", fontSize: 14, fontWeight: 700, letterSpacing: 3,
            cursor: "pointer",
            background: holes === h ? cardCream : "transparent",
            border: holes === h ? `1.5px solid ${accentLime}` : `1.5px solid ${creamSubtle}`,
            borderRadius: 8,
            color: holes === h ? darkText : creamDim,
            boxShadow: holes === h ? `0 0 16px ${accentLimeGlow}` : "none",
            transition: "all 0.15s"
          }}>{h} HOLES</div>
        ))}

        <div style={{ width: 1, height: 36, background: creamSubtle, margin: "0 4px" }}/>

        {/* Random */}
        <div onClick={randomCourse} style={{
          padding: "14px 24px", fontSize: 14, fontWeight: 700, letterSpacing: 3,
          cursor: "pointer",
          background: "transparent", border: `1.5px solid ${creamSubtle}`, borderRadius: 8,
          color: cream, display: "flex", alignItems: "center", gap: 10,
          transition: "all 0.15s"
        }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <path d="M2 8 C2 4.7 4.7 2 8 2 C11.3 2 14 4.7 14 8" stroke={cream} strokeWidth="1.5" strokeLinecap="round"/>
            <polyline points="11,5 14,8 11,11" stroke={cream} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M14 8 C14 11.3 11.3 14 8 14 C4.7 14 2 11.3 2 8" stroke={cream} strokeWidth="1.5" strokeLinecap="round"/>
            <polyline points="5,11 2,8 5,5" stroke={cream} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          RANDOM
        </div>

        <div style={{ flex: 1 }}/>

        {/* Select / Play button */}
        <div style={{
          padding: "16px 56px", fontSize: 16, fontWeight: 800, letterSpacing: 5,
          cursor: c ? "pointer" : "not-allowed",
          background: c ? cardCream : "rgba(212,205,182,0.25)",
          border: c ? `1.5px solid ${accentLime}` : `1.5px solid ${creamSubtle}`,
          borderRadius: 8,
          color: c ? darkText : "rgba(44,58,42,0.4)",
          boxShadow: c ? `0 0 24px ${accentLimeGlow}` : "none",
          transition: "all 0.15s"
        }}>SELECT →</div>
      </div>

    </div>
  );
}
Object.assign(window, { CourseSelectScreen });
