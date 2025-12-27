import React from "react";
import {
  Box,
  Paper,
  Typography,
  Avatar,
  Chip,
  Button,
  TextField,
  CircularProgress,
  Alert,
  Snackbar,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Divider,
} from "@mui/material";

import {
  adminGetPendingContractors,
  adminUpdateContractorStatus,
} from "../Service/AdminContractorsApi";

function initials(nameOrEmail) {
  const s = (nameOrEmail || "").trim();
  if (!s) return "C";
  const parts = s.split(" ").filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return s[0].toUpperCase();
}

function getAvatarSrc(u) {
  // في API عندك ممكن يطلع profileImageUrl من controller
  if (u?.profileImageUrl) return u.profileImageUrl;
  if (u?.profileImage) return u.profileImage;
  return "";
}

export default function AdminPendingContractorsPage() {
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const [success, setSuccess] = React.useState("");

  const [items, setItems] = React.useState([]);
  const [search, setSearch] = React.useState("");

  // view contractor doc modal (اختياري)
  const [docOpen, setDocOpen] = React.useState(false);
  const [docUrl, setDocUrl] = React.useState("");

  const load = React.useCallback(async () => {
    setError("");
    setLoading(true);
    try {
      const data = await adminGetPendingContractors();
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
      return name.includes(q) || email.includes(q) || phone.includes(q);
    });
  }, [items, search]);

  const openDoc = (u) => {
    // controller عندك يرجّع contractorDocumentUrl
    const url = u?.contractorDocumentUrl || "";
    if (!url) {
      setError("No contractor document found for this user.");
      return;
    }
    setDocUrl(url);
    setDocOpen(true);
  };

  const closeDoc = () => {
    setDocOpen(false);
    setDocUrl("");
  };

  const doUpdateStatus = async (u, status) => {
    if (!u?._id) return;

    const msg =
      status === "verified"
        ? "Verify this contractor?"
        : "Reject this contractor verification?";
    if (!window.confirm(msg)) return;

    setError("");
    try {
      const res = await adminUpdateContractorStatus(u._id, { status });
      setSuccess(res?.message || `Contractor ${status}`);

      // remove from pending list
      setItems((prev) => prev.filter((x) => x._id !== u._id));
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Update failed");
    }
  };

  return (
    <Box sx={{ width: "100%", px: { xs: 2, md: 3 }, py: 2 }}>
      <Typography variant="h4" sx={{ fontWeight: 900, textAlign: "center", mb: 2 }}>
        Pending Contractors
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
            label="Search (name / email / phone)"
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
              key={u._id}
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
                {/* LEFT */}
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

                {/* CENTER */}
                <Box sx={{ textAlign: { xs: "left", md: "center" } }}>
                  <Typography sx={{ opacity: 0.75, fontSize: 14, mb: 0.3 }}>Phone</Typography>
                  <Typography sx={{ fontWeight: 900, fontSize: 20 }}>{u?.phone || "—"}</Typography>
                </Box>

                {/* RIGHT */}
                <Box
                  sx={{
                    display: "flex",
                    justifyContent: { xs: "flex-start", md: "flex-end" },
                    alignItems: "center",
                    gap: 1.2,
                    flexWrap: "wrap",
                  }}
                >
                  <Chip label="Contractor" sx={{ fontWeight: 800 }} />
                  <Chip label="pending" variant="outlined" sx={{ fontWeight: 800 }} />

                  <Button variant="outlined" onClick={() => openDoc(u)} sx={{ fontWeight: 900 }}>
                    VIEW DOC
                  </Button>

                  <Button
                    variant="contained"
                    onClick={() => doUpdateStatus(u, "verified")}
                    sx={{ fontWeight: 900 }}
                  >
                    VERIFY
                  </Button>

                  <Button
                    variant="outlined"
                    onClick={() => doUpdateStatus(u, "rejected")}
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
              No pending contractors.
            </Typography>
          ) : null}
        </Box>
      )}

      {/* DOC MODAL */}
      <Dialog open={docOpen} onClose={closeDoc} fullWidth maxWidth="md">
        <DialogTitle sx={{ fontWeight: 900 }}>Contractor Document</DialogTitle>
        <DialogContent>
          <Divider sx={{ mb: 2 }} />
          {docUrl ? (
            <img
              alt="contractor-document"
              src={docUrl}
              style={{ width: "100%", borderRadius: 12, display: "block" }}
            />
          ) : (
            <Typography sx={{ opacity: 0.7 }}>No document</Typography>
          )}
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={closeDoc}>Close</Button>
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
