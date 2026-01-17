import React, { useRef, useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  TextField,
  Button,
  Alert,
  Avatar,
  CircularProgress,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid,
  Container,
  Paper,
  Divider,
  Stack,
  Chip
} from "@mui/material";

// Icons
import PhotoCamera from "@mui/icons-material/PhotoCamera";
import SaveIcon from "@mui/icons-material/Save";
import LockIcon from "@mui/icons-material/Lock";
import PersonOutlineIcon from "@mui/icons-material/PersonOutline";
import PhoneIphoneIcon from "@mui/icons-material/PhoneIphone";
import MailOutlineIcon from "@mui/icons-material/MailOutline";
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';

import { adminGetMe, adminUpdateMe, adminChangePassword } from "../Service/AdminMeApi";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";
const SESSION_KEY = "admin_session";

function toFullImageUrl(pathOrUrl) {
  if (!pathOrUrl) return "";
  if (pathOrUrl.startsWith("http")) return pathOrUrl;
  return `${API_BASE}${pathOrUrl}`;
}

export default function AdminProfile() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [me, setMe] = useState(null);

  // Form States
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [pickedFile, setPickedFile] = useState(null);
  const [previewImg, setPreviewImg] = useState(null);

  // Password Modal
  const [pwOpen, setPwOpen] = useState(false);
  const [pwLoading, setPwLoading] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");

  const fileInputRef = useRef(null);

  const load = useCallback(async () => {
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

  useEffect(() => {
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
        user: { ...s.user, ...updatedUser, image: fullImg },
      };
      localStorage.setItem(SESSION_KEY, JSON.stringify(next));
    } catch {}
  };

  const openFilePicker = () => fileInputRef.current?.click();
  
  const handlePickFile = (e) => {
    const file = e.target.files?.[0];
    if (file) {
        setPickedFile(file);
        setPreviewImg(URL.createObjectURL(file));
    }
  };

  const handleUpdate = async () => {
    setError("");
    setSuccess("");
    setSaving(true);
    try {
      const res = await adminUpdateMe({ name, phone, profileImageFile: pickedFile });
      setSuccess(res?.message || "Profile updated successfully");
      const updatedUser = res?.user;
      setMe(updatedUser);
      updateSessionUser(updatedUser);
      setPickedFile(null);
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Update failed");
    } finally {
      setSaving(false);
    }
  };

  const handleChangePassword = async () => {
    setError("");
    setSuccess("");
    setPwLoading(true);
    try {
      const res = await adminChangePassword({ currentPassword, newPassword });
      setSuccess(res?.message || "Password changed successfully");
      setPwOpen(false);
      setCurrentPassword("");
      setNewPassword("");
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Change password failed");
    } finally {
      setPwLoading(false);
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", height: "80vh" }}>
        <CircularProgress />
      </Box>
    );
  }

  const avatarSrc = previewImg || toFullImageUrl(me?.profileImage);

  return (
    // استخدمنا Container xl ليكون العرض واسع ومريح للعين
    <Container maxWidth="xl" sx={{ py: 4 }}>
      
      {/* Header Title */}
      <Typography variant="h4" sx={{ fontWeight: 800, mb: 4, letterSpacing: 1 }}>
        Account Settings
      </Typography>

      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 3 }}>{success}</Alert>}

      <Grid container spacing={4}>
        
        {/* === LEFT COLUMN: User Identity Card === */}
        <Grid item xs={12} md={4} lg={3}>
          <Paper 
            elevation={3} 
            sx={{ 
              p: 4, 
              textAlign: "center", 
              borderRadius: 4,
              bgcolor: 'rgba(30,30,30, 0.6)', 
              backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.08)'
            }}
          >
            <Box position="relative" display="inline-block" mb={2}>
              <Avatar
                src={avatarSrc}
                sx={{ width: 140, height: 140, mx: "auto", border: '4px solid #333' }}
              />
              <IconButton
                onClick={openFilePicker}
                sx={{
                  position: "absolute",
                  bottom: 5,
                  right: 5,
                  bgcolor: "primary.main",
                  color: "white",
                  "&:hover": { bgcolor: "primary.dark" },
                  width: 40, height: 40
                }}
              >
                <PhotoCamera fontSize="small" />
              </IconButton>
              <input ref={fileInputRef} hidden type="file" accept="image/*" onChange={handlePickFile} />
            </Box>

            <Typography variant="h5" fontWeight="bold" gutterBottom>
              {me?.name}
            </Typography>
            
            <Chip 
              icon={<AdminPanelSettingsIcon fontSize="small"/>} 
              label={me?.role?.toUpperCase()} 
              color="primary" 
              variant="outlined" 
              size="small" 
              sx={{ mb: 3, fontWeight: 'bold' }} 
            />

            <Divider sx={{ my: 2, borderColor: 'rgba(255,255,255,0.1)' }} />

            <Stack spacing={2} sx={{ textAlign: 'left', mt: 3 }}>
                <Box display="flex" alignItems="center" gap={2} sx={{ opacity: 0.8 }}>
                    <MailOutlineIcon color="action" />
                    <Typography variant="body2">{me?.email}</Typography>
                </Box>
                <Box display="flex" alignItems="center" gap={2} sx={{ opacity: 0.8 }}>
                    <PhoneIphoneIcon color="action" />
                    <Typography variant="body2">{phone || "No phone added"}</Typography>
                </Box>
            </Stack>
          </Paper>
        </Grid>

        {/* === RIGHT COLUMN: Edit Form & Security === */}
        <Grid item xs={12} md={8} lg={9}>
          <Paper 
            elevation={3} 
            sx={{ 
                p: { xs: 3, md: 5 }, 
                borderRadius: 4,
                bgcolor: 'rgba(30,30,30, 0.6)', 
                backdropFilter: 'blur(10px)',
                border: '1px solid rgba(255,255,255,0.08)'
            }}
          >
            {/* Section 1: Basic Info */}
            <Box mb={4}>
                <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
                    <PersonOutlineIcon color="primary" /> Basic Information
                </Typography>
                
                <Grid container spacing={3}>
                    <Grid item xs={12} md={6}>
                        <TextField
                            fullWidth
                            label="Full Name"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            variant="outlined"
                        />
                    </Grid>
                    <Grid item xs={12} md={6}>
                        <TextField
                            fullWidth
                            label="Phone Number"
                            value={phone}
                            onChange={(e) => setPhone(e.target.value)}
                            variant="outlined"
                        />
                    </Grid>
                    <Grid item xs={12}>
                        <TextField
                            fullWidth
                            label="Email (Read Only)"
                            value={me?.email || ""}
                            disabled
                            variant="filled"
                        />
                    </Grid>
                </Grid>

                <Box mt={3} display="flex" justifyContent="flex-end">
                    <Button 
                        variant="contained" 
                        size="large"
                        startIcon={<SaveIcon />}
                        onClick={handleUpdate}
                        disabled={saving}
                        sx={{ px: 4, py: 1, borderRadius: 2 }}
                    >
                        {saving ? "Saving..." : "Save Changes"}
                    </Button>
                </Box>
            </Box>

            <Divider sx={{ my: 4, borderColor: 'rgba(255,255,255,0.1)' }} />

            {/* Section 2: Security */}
            <Box>
                <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                    <LockIcon color="error" /> Security & Password
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                    Ensure your account is using a long, random password to stay secure.
                </Typography>

                <Button 
                    variant="outlined" 
                    color="error" 
                    size="large"
                    onClick={() => setPwOpen(true)}
                    sx={{ px: 4, py: 1, borderRadius: 2 }}
                >
                    Change Password
                </Button>
            </Box>
          </Paper>
        </Grid>
      </Grid>

      {/* Password Dialog */}
      <Dialog 
        open={pwOpen} 
        onClose={() => !pwLoading && setPwOpen(false)} 
        fullWidth 
        maxWidth="sm"
        PaperProps={{ sx: { borderRadius: 3, p: 1, bgcolor: '#1e1e1e' } }}
      >
        <DialogTitle sx={{ fontWeight: 800 }}>Change Password</DialogTitle>
        <DialogContent>
          <Box sx={{ display: "grid", gap: 3, mt: 1 }}>
            <TextField
              label="Current Password"
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              fullWidth
            />
            <TextField
              label="New Password"
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              fullWidth
              helperText="Must be at least 8 characters."
            />
          </Box>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 3 }}>
          <Button onClick={() => setPwOpen(false)} color="inherit">Cancel</Button>
          <Button
            variant="contained"
            color="primary"
            onClick={handleChangePassword}
            disabled={pwLoading || !currentPassword || !newPassword}
          >
            {pwLoading ? "Updating..." : "Confirm"}
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}