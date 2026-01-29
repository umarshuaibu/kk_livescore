/// Represents all possible views that can be rendered
/// inside the Admin Dashboard main content area.
///
/// IMPORTANT:
/// - Do NOT put routing logic here
/// - This enum is used ONLY for in-body navigation/state
enum AdminBodyView {
  // ================= CORE / OVERVIEW =================
  dashboard,

  // ================= LIVE MATCH =================
  liveMatchUpdater,

  // ================= PLAYERS =================
  players,           // player list
  createPlayer,      // create new player
  editPlayer,        // edit existing player
  transferPlayer,    // transfer workflow

  // ================= TEAMS =================
  teams,             // team list
  createTeam,
  editTeam,

  // ================= COACHES =================
  coaches,
  createCoach,
  editCoach,

  // ================= LEAGUES =================
  leagues,
  createLeague,
  editLeague,

  // ================= TRANSFERS =================
  transfers,
  createTransfer,

  // ================= NEWS =================
  news,
  createNews,
  editNews,
}
