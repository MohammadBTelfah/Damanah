import React from "react";
import {
  Box,
  Paper,
  Typography,
  Avatar,
  Chip,
  Button,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Divider,
  CircularProgress,
  Alert,
  Snackbar,
} from "@mui/material";

import {
  adminGetPendingIdentities,
  adminGetIdentityDetails,
  adminUpdateIdentityStatus,
} from "../Service/AdminIdentityApi";

function initials(nameOrEmail) {
  const s = (nameOrEmail || "").trim();
  if (!s) return "U";
  const parts = s.split(" ").filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return s[0].toUpperCase();
}

function getAvatarSrc(u) {
  if (u?.profileImageUrl) return u.profileImageUrl;
  if (u?.profileImage) return u.profileImage;
  return "";
}

export default function AdminIdentityPendingPage() {
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const [success, setSuccess] = React.useState("");

  const [items, setItems] = React.useState([]);
  const [search, setSearch] = React.useState("");

  // View modal
  const [viewOpen, setViewOpen] = React.useState(false);
  const [viewLoading, setViewLoading] = React.useState(false);
  const [selected, setSelected] = React.useState(null);
  const [details, setDetails] = React.useState(null);

  // Verify modal (optional nationalId)
  const [verifyOpen, setVerifyOpen] = React.useState(false);
  const [verifyLoading, setVerifyLoading] = React.useState(false);
  const [nationalId, setNationalId] = React.useState("");

  const load = React.useCallback(async () => {
    setError("");
    setLoading(true);
    try {
      const data = await adminGetPendingIdentities();
      setItems(Array.isArray(data) ? data : []);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Failed to load");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    load();
  }, [load]);

  const filtered = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((u) => {
      const name = (u?.name || "").toLowerCase();
      const email = (u?.email || "").toLowerCase();
      const phone = (u?.phone || "").toLowerCase();
      const role = (u?.role || "").toLowerCase();
      return name.includes(q) || email.includes(q) || phone.includes(q) || role.includes(q);
    });
  }, [items, search]);

  const openView = async (u) => {
    setSelected(u);
    setDetails(null);
    setViewOpen(true);
    setViewLoading(true);
    setError("");
    try {
      const data = await adminGetIdentityDetails(u.role, u._id);
      setDetails(data);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Failed to load identity");
    } finally {
      setViewLoading(false);
    }
  };

  const closeView = () => {
    if (viewLoading) return;
    setViewOpen(false);
    setSelected(null);
    setDetails(null);
  };

  const openVerify = (u) => {
    setSelected(u);
    setNationalId(u?.nationalId || "");
    setVerifyOpen(true);
  };

  const closeVerify = () => {
    if (verifyLoading) return;
    setVerifyOpen(false);
  };

  const doVerify = async () => {
    if (!selected?._id || !selected?.role) return;
    setVerifyLoading(true);
    setError("");
    try {
      const payload = { status: "verified" };
      if (nationalId.trim()) payload.nationalId = nationalId.trim();

      const res = await adminUpdateIdentityStatus(selected.role, selected._id, payload);
      setSuccess(res?.message || "Identity verified");

      // remove from pending list
      setItems((prev) => prev.filter((x) => !(x._id === selected._id && x.role === selected.role)));

      setVerifyOpen(false);
      setViewOpen(false);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Verify failed");
    } finally {
      setVerifyLoading(false);
    }
  };

  const doReject = async (u) => {
    if (!window.confirm("Reject this identity request?")) return;
    setError("");
    try {
      const res = await adminUpdateIdentityStatus(u.role, u._id, { status: "rejected" });
      setSuccess(res?.message || "Identity rejected");
      setItems((prev) => prev.filter((x) => !(x._id === u._id && x.role === u.role)));
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Reject failed");
    }
  };

  return (
    <Box sx={{ width: "100%", px: { xs: 2, md: 3 }, py: 2 }}>
      <Typography variant="h4" sx={{ fontWeight: 900, textAlign: "center", mb: 2 }}>
        Pending Identity
      </Typography>

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      <Paper
        sx={{
          p: 2,
          borderRadius: 3,
          mb: 2,
          bgcolor: "rgba(255,255,255,0.03)",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <Box
          sx={{
            display: "grid",
            gridTemplateColumns: { xs: "1fr", md: "1fr 140px" },
            gap: 2,
            alignItems: "center",
          }}
        >
          <TextField
            label="Search (name / email / phone / role)"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            fullWidth
          />
          <Button variant="outlined" onClick={load} disabled={loading} sx={{ fontWeight: 900, py: 1.4 }}>
            {loading ? "Loading..." : "REFRESH"}
          </Button>
        </Box>
      </Paper>

      {loading ? (
        <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
          <CircularProgress />
        </Box>
      ) : (
        <Box sx={{ display: "grid", gap: 2 }}>
          {filtered.map((u) => (
            <Paper
              key={`${u.role}-${u._id}`}
              sx={{
                p: 2.2,
                borderRadius: 3,
                bgcolor: "rgba(255,255,255,0.03)",
                border: "1px solid rgba(255,255,255,0.08)",
                boxShadow: "0 10px 30px rgba(0,0,0,0.35)",
              }}
            >
              <Box
                sx={{
                  display: "grid",
                  gridTemplateColumns: { xs: "1fr", md: "420px 1fr 520px" },
                  gap: 2,
                  alignItems: "center",
                }}
              >
                {/* LEFT: avatar + name/email */}
                <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
                  <Avatar
                    src={getAvatarSrc(u)}
                    sx={{
                      width: 56,
                      height: 56,
                      bgcolor: "rgba(255,255,255,0.12)",
                      border: "1px solid rgba(255,255,255,0.1)",
                    }}
                  >
                    {initials(u?.name || u?.email)}
                  </Avatar>

                  <Box sx={{ minWidth: 0 }}>
                    <Typography sx={{ fontWeight: 900, fontSize: 20, lineHeight: 1.1 }}>
                      {u?.name || "—"}
                    </Typography>
                    <Typography sx={{ opacity: 0.75, fontSize: 14 }}>
                      {u?.email || "—"}
                    </Typography>
                  </Box>
                </Box>

                {/* CENTER: phone */}
                <Box sx={{ textAlign: { xs: "left", md: "center" } }}>
                  <Typography sx={{ opacity: 0.75, fontSize: 14, mb: 0.3 }}>Phone</Typography>
                  <Typography sx={{ fontWeight: 900, fontSize: 20 }}>{u?.phone || "—"}</Typography>
                </Box>

                {/* RIGHT: chips + actions */}
                <Box
                  sx={{
                    display: "flex",
                    justifyContent: { xs: "flex-start", md: "flex-end" },
                    alignItems: "center",
                    gap: 1.2,
                    flexWrap: "wrap",
                  }}
                >
                  <Chip
                    label={(u?.role || "").charAt(0).toUpperCase() + (u?.role || "").slice(1)}
                    sx={{ fontWeight: 800 }}
                  />
                  <Chip label="pending" variant="outlined" sx={{ fontWeight: 800 }} />

                  <Button variant="outlined" onClick={() => openView(u)} sx={{ fontWeight: 900 }}>
                    VIEW ID
                  </Button>

                  <Button variant="contained" onClick={() => openVerify(u)} sx={{ fontWeight: 900 }}>
                    VERIFY
                  </Button>

                  <Button
                    variant="outlined"
                    onClick={() => doReject(u)}
                    sx={{
                      fontWeight: 900,
                      borderColor: "rgba(244, 67, 54, 0.7)",
                      color: "rgba(244, 67, 54, 0.95)",
                      "&:hover": { borderColor: "rgba(244, 67, 54, 1)" },
                    }}
                  >
                    REJECT
                  </Button>
                </Box>
              </Box>
            </Paper>
          ))}

          {filtered.length === 0 ? (
            <Typography sx={{ opacity: 0.7, textAlign: "center", py: 6 }}>
              No pending identities.
            </Typography>
          ) : null}
        </Box>
      )}

      {/* VIEW MODAL */}
      <Dialog open={viewOpen} onClose={closeView} fullWidth maxWidth="md">
        <DialogTitle sx={{ fontWeight: 900 }}>Identity Details</DialogTitle>
        <DialogContent>
          <Divider sx={{ mb: 2 }} />

          {viewLoading ? (
            <Box sx={{ display: "flex", justifyContent: "center", py: 5 }}>
              <CircularProgress />
            </Box>
          ) : (
            <Box sx={{ display: "grid", gap: 2 }}>
              <Alert severity="info">
                {details?.name} — {details?.email} — role: <b>{details?.role}</b>
              </Alert>

              <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", md: "1fr 1fr" }, gap: 2 }}>
                <Paper sx={{ p: 2, borderRadius: 2 }}>
                  <Typography sx={{ fontWeight: 900, mb: 1 }}>Identity Document</Typography>
                  {details?.identityDocumentUrl ? (
                    <img
                      alt="identity"
                      src={details.identityDocumentUrl}
                      style={{ width: "100%", borderRadius: 12, display: "block" }}
                    />
                  ) : (
                    <Typography sx={{ opacity: 0.7 }}>No document</Typography>
                  )}
                </Paper>

                <Paper sx={{ p: 2, borderRadius: 2 }}>
                  <Typography sx={{ fontWeight: 900, mb: 1 }}>Info</Typography>
                  <Typography sx={{ opacity: 0.85 }}>
                    Status: <b>{details?.identityStatus || "pending"}</b>
                  </Typography>
                  <Typography sx={{ opacity: 0.85 }}>
                    National ID: <b>{details?.nationalId || "—"}</b>
                  </Typography>
                </Paper>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={closeView}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* VERIFY MODAL */}
      <Dialog open={verifyOpen} onClose={closeVerify} fullWidth maxWidth="sm">
        <DialogTitle sx={{ fontWeight: 900 }}>Verify identity</DialogTitle>
        <DialogContent>
          <Divider sx={{ mb: 2 }} />
          <TextField
            label="National ID (optional)"
            fullWidth
            value={nationalId}
            onChange={(e) => setNationalId(e.target.value)}
            helperText="If you want to store extracted National ID."
          />
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={closeVerify} disabled={verifyLoading}>
            Cancel
          </Button>
          <Button
            variant="contained"
            onClick={doVerify}
            disabled={verifyLoading}
            sx={{ fontWeight: 900 }}
          >
            {verifyLoading ? "Saving..." : "Verify"}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={!!success}
        autoHideDuration={2200}
        onClose={() => setSuccess("")}
        message={success}
      />
    </Box>
  );
}
