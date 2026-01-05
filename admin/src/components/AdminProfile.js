import React from "react";
import {
  Box,
  Typography,
  TextField,
  Button,
  Alert,
  Avatar,
  CircularProgress,
  Divider,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Tooltip,
} from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import PhotoCameraIcon from "@mui/icons-material/PhotoCamera";
import LockResetIcon from "@mui/icons-material/LockReset";
import CloseIcon from "@mui/icons-material/Close";
import SaveIcon from "@mui/icons-material/Save";

import { adminGetMe, adminUpdateMe, adminChangePassword } from "../Service/AdminMeApi";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const SESSION_KEY = "admin_session";

function toFullImageUrl(pathOrUrl) {
  if (!pathOrUrl) return "";
  if (pathOrUrl.startsWith("http")) return pathOrUrl;
  return `${API_BASE}${pathOrUrl}`;
}

export default function AdminProfile() {
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);

  const [error, setError] = React.useState("");
  const [success, setSuccess] = React.useState("");

  const [me, setMe] = React.useState(null);

  const [name, setName] = React.useState("");
  const [phone, setPhone] = React.useState("");
  const [pickedFile, setPickedFile] = React.useState(null);

  const [isEditingName, setIsEditingName] = React.useState(false);

  // password modal
  const [pwOpen, setPwOpen] = React.useState(false);
  const [pwLoading, setPwLoading] = React.useState(false);
  const [currentPassword, setCurrentPassword] = React.useState("");
  const [newPassword, setNewPassword] = React.useState("");

  const fileInputRef = React.useRef(null);

  const load = React.useCallback(async () => {
    setError("");
    setSuccess("");
    setLoading(true);
    try {
      const data = await adminGetMe();
      const user = data?.user;
      setMe(user);
      setName(user?.name || "");
      setPhone(user?.phone || "");
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Failed to load profile");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    load();
  }, [load]);

  const updateSessionUser = (updatedUser) => {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      if (!raw) return;

      const s = JSON.parse(raw);
      const rawImg = updatedUser?.profileImage;
      const fullImg = rawImg ? toFullImageUrl(rawImg) : s?.user?.image;

      const next = {
        ...s,
        user: {
          ...s.user,
          name: updatedUser?.name ?? s.user?.name,
          email: updatedUser?.email ?? s.user?.email,
          image: fullImg,
        },
      };
      localStorage.setItem(SESSION_KEY, JSON.stringify(next));
    } catch {}
  };

  const openFilePicker = () => fileInputRef.current?.click();
  const handlePickFile = (e) => setPickedFile(e.target.files?.[0] || null);

  const handleUpdate = async () => {
    setError("");
    setSuccess("");
    setSaving(true);
    try {
      const res = await adminUpdateMe({ name, phone, profileImageFile: pickedFile });
      setSuccess(res?.message || "Account updated");

      const updatedUser = res?.user;
      setMe(updatedUser);
      updateSessionUser(updatedUser);

      setPickedFile(null);
      setIsEditingName(false);
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Update failed");
    } finally {
      setSaving(false);
    }
  };

  const handleOpenPw = () => {
    setError("");
    setSuccess("");
    setCurrentPassword("");
    setNewPassword("");
    setPwOpen(true);
  };

  const handleChangePassword = async () => {
    setError("");
    setSuccess("");
    setPwLoading(true);
    try {
      const res = await adminChangePassword({ currentPassword, newPassword });
      setSuccess(res?.message || "Password changed successfully");
      setPwOpen(false);
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Change password failed");
    } finally {
      setPwLoading(false);
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
        <CircularProgress />
      </Box>
    );
  }

  const avatarSrc = toFullImageUrl(me?.profileImage);

  return (
    <Box sx={{ width: "100%", p: { xs: 2, md: 3 } }}>
      {/* ===== Title ===== */}
      <Typography variant="h4" sx={{ fontWeight: 900, mb: 2 }}>
        Admin Profile
      </Typography>

      {error ? <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert> : null}
      {success ? <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert> : null}

      {/* ===== Header Bar (Full width) ===== */}
      <Box
        sx={{
          width: "100%",
          borderRadius: 3,
          p: 2.5,
          border: "1px solid rgba(255,255,255,0.08)",
          bgcolor: "rgba(255,255,255,0.03)",
          display: "flex",
          alignItems: "center",
          gap: 2,
        }}
      >
        {/* avatar */}
        <Box sx={{ position: "relative" }}>
          <Avatar src={avatarSrc} sx={{ width: 84, height: 84 }} />
          <Tooltip title="Change photo">
            <IconButton
              onClick={openFilePicker}
              sx={{
                position: "absolute",
                right: -6,
                bottom: -6,
                bgcolor: "rgba(0,0,0,0.6)",
                border: "1px solid rgba(255,255,255,0.12)",
                "&:hover": { bgcolor: "rgba(0,0,0,0.8)" },
              }}
            >
              <PhotoCameraIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <input ref={fileInputRef} hidden type="file" accept="image/*" onChange={handlePickFile} />
        </Box>

        {/* name */}
        <Box sx={{ flex: 1, minWidth: 240 }}>
          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            {!isEditingName ? (
              <>
                <Typography sx={{ fontWeight: 900, fontSize: 20 }}>
                  {me?.name || "—"}
                </Typography>
                <Tooltip title="Edit name">
                  <IconButton size="small" onClick={() => setIsEditingName(true)}>
                    <EditIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </>
            ) : (
              <>
                <TextField
                  size="small"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  sx={{ maxWidth: 320 }}
                />
                <Tooltip title="Done">
                  <IconButton size="small" onClick={() => setIsEditingName(false)}>
                    <SaveIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
                <Tooltip title="Cancel">
                  <IconButton
                    size="small"
                    onClick={() => {
                      setName(me?.name || "");
                      setIsEditingName(false);
                    }}
                  >
                    <CloseIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </>
            )}
          </Box>

          {pickedFile ? (
            <Typography sx={{ mt: 0.5, opacity: 0.75, fontSize: 13 }}>
              Selected image: {pickedFile.name}
            </Typography>
          ) : null}
        </Box>

        {/* actions right */}
        <Box sx={{ display: "flex", gap: 1 }}>
          <Button
            startIcon={<LockResetIcon />}
            variant="outlined"
            onClick={handleOpenPw}
            sx={{ fontWeight: 900 }}
          >
            Change Password
          </Button>

          <Button
            variant="contained"
            onClick={handleUpdate}
            disabled={saving}
            sx={{ fontWeight: 900 }}
          >
            {saving ? "Saving..." : "Save"}
          </Button>
        </Box>
      </Box>

      <Divider sx={{ my: 2.5 }} />

      {/* ===== Settings Body (full width, clean) ===== */}
      <Typography sx={{ fontWeight: 900, mb: 1.5 }}>Contact info</Typography>

      <Box
        sx={{
          width: "100%",
          display: "grid",
          gridTemplateColumns: { xs: "1fr", md: "1fr 1fr" },
          gap: 2,
        }}
      >
        <TextField label="Email" value={me?.email || ""} disabled fullWidth />
        <TextField
          label="Phone"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          fullWidth
        />
      </Box>

      {/* ===== Password Modal ===== */}
      <Dialog open={pwOpen} onClose={() => !pwLoading && setPwOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle sx={{ fontWeight: 900 }}>Change password</DialogTitle>
        <DialogContent sx={{ pt: 1 }}>
          <Box sx={{ display: "grid", gap: 2, mt: 1 }}>
            <TextField
              label="Current password"
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              fullWidth
            />
            <TextField
              label="New password"
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              helperText="Min 8 chars, uppercase, lowercase, number, special char."
              fullWidth
            />
          </Box>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setPwOpen(false)} disabled={pwLoading}>
            Cancel
          </Button>
          <Button
            variant="contained"
            onClick={handleChangePassword}
            disabled={pwLoading || !currentPassword || !newPassword}
            sx={{ fontWeight: 900 }}
          >
            {pwLoading ? "Updating..." : "Update"}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
