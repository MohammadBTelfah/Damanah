import React from "react";
import {
  Box,
  Paper,
  Typography,
  TextField,
  Button,
  MenuItem,
  Select,
  FormControl,
  InputLabel,
  Avatar,
  Chip,
  CircularProgress,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Divider,
  Snackbar,
} from "@mui/material";

import {
  adminGetUsers,
  adminUpdateUser,
  adminDeleteUser,
  adminToggleUserActive,
} from "../Service/AdminUsersApi";

function getAvatarSrc(u) {
  // الباك اند عندك بيرجع profileImageUrl جاهز (full url)
  if (u?.profileImageUrl) return u.profileImageUrl;
  // احتياط لو رجع profileImage فقط
  if (u?.profileImage) return u.profileImage;
  return "";
}

function initials(nameOrEmail) {
  const s = (nameOrEmail || "").trim();
  if (!s) return "U";
  const parts = s.split(" ").filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return s[0].toUpperCase();
}

export default function AdminUsersPage() {
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const [success, setSuccess] = React.useState("");

  const [roleFilter, setRoleFilter] = React.useState(""); // "", client, contractor, admin
  const [search, setSearch] = React.useState("");

  const [users, setUsers] = React.useState([]);

  // Edit modal
  const [editOpen, setEditOpen] = React.useState(false);
  const [editSaving, setEditSaving] = React.useState(false);
  const [selected, setSelected] = React.useState(null);
  const [editName, setEditName] = React.useState("");
  const [editEmail, setEditEmail] = React.useState("");
  const [editPhone, setEditPhone] = React.useState("");

  const load = React.useCallback(async () => {
    setError("");
    setLoading(true);
    try {
      const data = await adminGetUsers(roleFilter || undefined);
      setUsers(Array.isArray(data) ? data : []);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Failed to load users");
    } finally {
      setLoading(false);
    }
  }, [roleFilter]);

  React.useEffect(() => {
    load();
  }, [load]);

  const filtered = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return users;

    return users.filter((u) => {
      const name = (u?.name || "").toLowerCase();
      const email = (u?.email || "").toLowerCase();
      const phone = (u?.phone || "").toLowerCase();
      return name.includes(q) || email.includes(q) || phone.includes(q);
    });
  }, [users, search]);

  const openEdit = (u) => {
    setSelected(u);
    setEditName(u?.name || "");
    setEditEmail(u?.email || "");
    setEditPhone(u?.phone || "");
    setEditOpen(true);
  };

  const closeEdit = () => {
    if (editSaving) return;
    setEditOpen(false);
    setSelected(null);
  };

  const doUpdate = async () => {
    if (!selected?._id || !selected?.role) return;
    setEditSaving(true);
    setError("");
    try {
      const payload = {
        name: editName,
        email: editEmail,
        phone: editPhone,
      };
      const res = await adminUpdateUser(selected.role, selected._id, payload);
      setSuccess(res?.message || "User updated");

      // update list locally
      setUsers((prev) =>
        prev.map((x) => (x._id === selected._id && x.role === selected.role ? res.user : x))
      );

      setEditOpen(false);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Update failed");
    } finally {
      setEditSaving(false);
    }
  };

  const doDelete = async (u) => {
    if (!window.confirm("Are you sure you want to delete this user?")) return;
    setError("");
    try {
      const res = await adminDeleteUser(u.role, u._id);
      setSuccess(res?.message || "User deleted");
      setUsers((prev) => prev.filter((x) => !(x._id === u._id && x.role === u.role)));
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Delete failed");
    }
  };

  const doToggleActive = async (u) => {
    setError("");
    try {
      const res = await adminToggleUserActive(u.role, u._id);
      setSuccess(res?.message || "Status updated");
      setUsers((prev) =>
        prev.map((x) => (x._id === u._id && x.role === u.role ? res.user : x))
      );
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e?.message || "Toggle failed");
    }
  };

  return (
    <Box sx={{ width: "100%", px: { xs: 2, md: 3 }, py: 2 }}>
      <Typography
        variant="h4"
        sx={{ fontWeight: 900, textAlign: "center", mb: 2, letterSpacing: 0.5 }}
      >
        Users
      </Typography>

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      {/* Top filters (same bar style as your screenshot) */}
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
            gridTemplateColumns: { xs: "1fr", md: "260px 1fr 140px" },
            gap: 2,
            alignItems: "center",
          }}
        >
          <FormControl fullWidth>
            <InputLabel id="role-label">Role</InputLabel>
            <Select
              labelId="role-label"
              label="Role"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
            >
              <MenuItem value="">All</MenuItem>
              <MenuItem value="client">Client</MenuItem>
              <MenuItem value="contractor">Contractor</MenuItem>
              <MenuItem value="admin">Admin</MenuItem>
            </Select>
          </FormControl>

          <TextField
            label="Search (name / email / phone)"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            fullWidth
          />

          <Button
            variant="outlined"
            onClick={load}
            disabled={loading}
            sx={{ fontWeight: 900, py: 1.4 }}
          >
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
          {filtered.map((u) => {
            const avatar = getAvatarSrc(u);
            const isActive = u?.isActive === true;

            return (
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
                    gridTemplateColumns: { xs: "1fr", md: "420px 1fr 420px" },
                    gap: 2,
                    alignItems: "center",
                  }}
                >
                  {/* LEFT: avatar + name/email */}
                  <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
                    <Avatar
                      src={avatar}
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
                      <Typography
                        sx={{
                          opacity: 0.75,
                          fontSize: 14,
                          whiteSpace: "nowrap",
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          maxWidth: 320,
                        }}
                      >
                        {u?.email || "—"}
                      </Typography>
                    </Box>
                  </Box>

                  {/* CENTER: phone */}
                  <Box sx={{ textAlign: { xs: "left", md: "center" } }}>
                    <Typography sx={{ opacity: 0.75, fontSize: 14, mb: 0.3 }}>
                      Phone
                    </Typography>
                    <Typography sx={{ fontWeight: 900, fontSize: 20 }}>
                      {u?.phone || "—"}
                    </Typography>
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

                    <Chip
                      label={isActive ? "Active" : "Disabled"}
                      variant="outlined"
                      sx={{
                        fontWeight: 800,
                        borderColor: isActive ? "rgba(76, 175, 80, 0.8)" : "rgba(255,255,255,0.2)",
                        color: isActive ? "rgba(76, 175, 80, 0.95)" : "rgba(255,255,255,0.7)",
                      }}
                    />

                    <Button
                      variant="outlined"
                      onClick={() => doToggleActive(u)}
                      sx={{ fontWeight: 900 }}
                    >
                      {isActive ? "DISABLE" : "ENABLE"}
                    </Button>

                    <Button
                      variant="contained"
                      onClick={() => openEdit(u)}
                      sx={{ fontWeight: 900 }}
                    >
                      EDIT
                    </Button>

                    <Button
                      variant="outlined"
                      onClick={() => doDelete(u)}
                      sx={{
                        fontWeight: 900,
                        borderColor: "rgba(244, 67, 54, 0.7)",
                        color: "rgba(244, 67, 54, 0.95)",
                        "&:hover": { borderColor: "rgba(244, 67, 54, 1)" },
                      }}
                    >
                      DELETE
                    </Button>
                  </Box>
                </Box>
              </Paper>
            );
          })}

          {filtered.length === 0 ? (
            <Typography sx={{ opacity: 0.7, textAlign: "center", py: 6 }}>
              No users found.
            </Typography>
          ) : null}
        </Box>
      )}

      {/* EDIT MODAL */}
      <Dialog open={editOpen} onClose={closeEdit} fullWidth maxWidth="sm">
        <DialogTitle sx={{ fontWeight: 900 }}>Edit user</DialogTitle>
        <DialogContent>
          <Divider sx={{ mb: 2 }} />

          <Box sx={{ display: "grid", gap: 2 }}>
            <TextField
              label="Name"
              value={editName}
              onChange={(e) => setEditName(e.target.value)}
              fullWidth
            />
            <TextField
              label="Email"
              value={editEmail}
              onChange={(e) => setEditEmail(e.target.value)}
              fullWidth
            />
            <TextField
              label="Phone"
              value={editPhone}
              onChange={(e) => setEditPhone(e.target.value)}
              fullWidth
            />

            <Alert severity="info">
              Role: <b>{selected?.role}</b>
            </Alert>
          </Box>
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={closeEdit} disabled={editSaving}>
            Cancel
          </Button>
          <Button
            variant="contained"
            onClick={doUpdate}
            disabled={editSaving}
            sx={{ fontWeight: 900 }}
          >
            {editSaving ? "Saving..." : "Save"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* SUCCESS TOAST */}
      <Snackbar
        open={!!success}
        autoHideDuration={2200}
        onClose={() => setSuccess("")}
        message={success}
      />
    </Box>
  );
}
