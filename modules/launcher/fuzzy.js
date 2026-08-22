// Fuzzy subsequence scoring for the app launcher.
// Higher is better; -1 means "no match". Pure functions, no QML imports.

function score(query, text) {
    const q = String(query ?? "").toLowerCase();
    const t = String(text ?? "").toLowerCase();
    if (q.length === 0)
        return 0;
    if (t.length === 0)
        return -1;

    let qi = 0;
    let streak = 0;
    let sc = 0;

    for (let ti = 0; ti < t.length && qi < q.length; ti++) {
        if (t[ti] === q[qi]) {
            sc += 10 + streak * 4;
            // boundary bonus: start of string or after a separator
            if (ti === 0 || /[\s\-_.]/.test(t[ti - 1]))
                sc += 12;
            streak++;
            qi++;
        } else {
            streak = 0;
        }
    }

    // exhausted target before query → not a subsequence
    if (qi < q.length)
        return -1;

    // prefer tighter names on ties
    return sc - Math.max(0, t.length - q.length) * 0.4;
}

// Composite score for one DesktopEntry across name/id/genericName/keywords.
function entryScore(query, entry) {
    const n = score(query, entry.name);
    const i = score(query, entry.id);
    const iAdj = i < 0 ? -1 : i * 0.9;
    let best = Math.max(n, iAdj);

    if (best > 0) {
        const g = score(query, entry.genericName);
        if (g > 0)
            best += g * 0.25;
        return best;
    }

    // keywords only rescue an otherwise-missed query at half weight
    try {
        const k = score(query, (entry.keywords ?? []).join(" "));
        if (k > 0)
            return k * 0.5;
    } catch (err) {}

    return -1;
}
