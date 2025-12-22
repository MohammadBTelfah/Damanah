import React, { useMemo, useRef, useState } from "react";
import {
  Box,
  Container,
  Typography,
  TextField,
  Button,
  Alert,
  IconButton,
  InputAdornment,
  Paper,
  CircularProgress,
  Avatar,
} from "@mui/material";
import Visibility from "@mui/icons-material/Visibility";
import VisibilityOff from "@mui/icons-material/VisibilityOff";
import { useNavigate } from "react-router-dom";
import { adminRegister, adminResendVerification } from "../Service/AuthApi";

const bgColor = "#0F261F";
const inputFill = "#1B3A35";
const primaryButton = "#8BE3B5";

export default function AdminRegister() {
  const navigate = useNavigate();
  const fileInputRef = useRef(null);

  const [form, setForm] = useState({
    name: "",
    email: "",
    password: "",
    phone: "",
    adminSecret: "",
  });

  // ✅ NEW: profile image file + preview
  const [profileImageFile, setProfileImageFile] = useState(null);
  const [profilePreview, setProfilePreview] = useState("");

  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [awaitingVerification, setAwaitingVerification] = useState(false);

  const canSubmit = useMemo(() => {
    return (
      form.name.trim() &&
      form.email.trim() &&
      form.password.trim() &&
      form.phone.trim() &&
      form.adminSecret.trim()
    );
  }, [form]);

  const handleChange = (key) => (e) => {
    setForm((prev) => ({ ...prev, [key]: e.target.value }));
  };

  const normalizeError = (err) => {
    return (
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      err?.message ||
      "Something went wrong"
    );
  };

  // ✅ NEW: handle image select
  const handlePickImage = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Optional: validate (images only)
    if (!file.type.startsWith("image/")) {
      setErrorMsg("Profile image must be an image file.");
      return;
    }

    setErrorMsg("");
    setProfileImageFile(file);

    const url = URL.createObjectURL(file);
    setProfilePreview(url);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg("");
    setSuccessMsg("");

    if (!canSubmit) {
      setErrorMsg("Please fill all required fields.");
      return;
    }

    setLoading(true);
    try {
      // ✅ IMPORTANT: use FormData for file upload
      const fd = new FormData();
      fd.append("name", form.name.trim());
      fd.append("email", form.email.trim());
      fd.append("password", form.password);
      fd.append("phone", form.phone.trim());

      // ✅ file field name must match backend multer: upload.single("profileImage")
      if (profileImageFile) fd.append("profileImage", profileImageFile);

      const data = await adminRegister(fd, form.adminSecret.trim());

      setAwaitingVerification(true);
      setSuccessMsg(
        data?.message ||
          "Registration successful. Please check your email and verify your account."
      );

      // اختياري: اقفل تعديل الحقول الحساسة
      setForm((prev) => ({
        ...prev,
        password: "",
        adminSecret: "",
      }));
    } catch (err) {
      setErrorMsg(normalizeError(err));
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    setErrorMsg("");
    setSuccessMsg("");
    setLoading(true);
    try {
      await adminResendVerification({ email: form.email.trim() });
      setSuccessMsg("Verification email re-sent. Please check your inbox.");
    } catch (err) {
      setErrorMsg(normalizeError(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: "100vh",
        backgroundColor: bgColor,
        display: "flex",
        alignItems: "center",
        py: 6,
      }}
    >
      <Container maxWidth="sm">
        <Paper
          elevation={10}
          sx={{
            p: 4,
            borderRadius: 3,
            backgroundColor: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)",
            backdropFilter: "blur(6px)",
          }}
        >
          <Typography variant="h5" sx={{ color: "white", fontWeight: 700, mb: 1 }}>
            Admin Registration
          </Typography>
          <Typography sx={{ color: "rgba(255,255,255,0.7)", mb: 3 }}>
            Create an admin account (requires admin secret).
          </Typography>

          {successMsg ? (
            <Alert severity="success" sx={{ mb: 2 }}>
              {successMsg}
            </Alert>
          ) : null}

          {errorMsg ? (
            <Alert severity="error" sx={{ mb: 2 }}>
              {errorMsg}
            </Alert>
          ) : null}

          {/* ✅ If registered: waiting verification */}
          {awaitingVerification ? (
            <Box sx={{ mt: 2 }}>
              <Alert severity="info" sx={{ mb: 2 }}>
                We sent a verification link to <b>{form.email}</b>. Please verify your
                email to activate your admin account.
              </Alert>

              <Button
                fullWidth
                onClick={handleResend}
                disabled={loading || !form.email.trim()}
                sx={{
                  mb: 1.5,
                  py: 1.2,
                  borderRadius: 2,
                  fontWeight: 800,
                  backgroundColor: "rgba(255,255,255,0.12)",
                  color: "white",
                  "&:hover": { backgroundColor: "rgba(255,255,255,0.18)" },
                }}
              >
                {loading ? (
                  <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                    <CircularProgress size={18} />
                    Sending...
                  </Box>
                ) : (
                  "Resend verification email"
                )}
              </Button>

              <Button
                fullWidth
                onClick={() => navigate("/admin/login")}
                sx={{
                  py: 1.2,
                  borderRadius: 2,
                  fontWeight: 900,
                  backgroundColor: primaryButton,
                  color: "#0B1A15",
                  "&:hover": { backgroundColor: primaryButton, opacity: 0.9 },
                }}
              >
                Go to Login
              </Button>

              <Typography sx={{ mt: 2, color: "rgba(255,255,255,0.55)", fontSize: 13 }}>
                After you click the verification link in your email, you’ll be redirected to
                the login page automatically.
              </Typography>
            </Box>
          ) : (
            <Box component="form" onSubmit={handleSubmit}>
              {/* ✅ NEW: Profile Image uploader (top, center) */}
              <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", mb: 2 }}>
                <Avatar
                  src={profilePreview || ""}
                  sx={{
                    width: 92,
                    height: 92,
                    mb: 1,
                    bgcolor: "rgba(255,255,255,0.12)",
                    border: "1px solid rgba(255,255,255,0.15)",
                  }}
                />
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  style={{ display: "none" }}
                  onChange={handlePickImage}
                />
                <Button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  sx={{
                    px: 2.5,
                    py: 0.9,
                    borderRadius: 2,
                    fontWeight: 800,
                    backgroundColor: "rgba(255,255,255,0.12)",
                    color: "white",
                    "&:hover": { backgroundColor: "rgba(255,255,255,0.18)" },
                  }}
                >
                  Upload Profile Image
                </Button>

                {profileImageFile ? (
                  <Typography sx={{ mt: 1, fontSize: 12, color: "rgba(255,255,255,0.6)" }}>
                    Selected: {profileImageFile.name}
                  </Typography>
                ) : (
                  <Typography sx={{ mt: 1, fontSize: 12, color: "rgba(255,255,255,0.6)" }}>
                    (Optional)
                  </Typography>
                )}
              </Box>

              <TextField
                fullWidth
                label="Full Name"
                value={form.name}
                onChange={handleChange("name")}
                margin="normal"
                autoComplete="name"
                InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
                InputProps={{
                  sx: { color: "white", backgroundColor: inputFill, borderRadius: 2 },
                }}
              />

              <TextField
                fullWidth
                label="Email"
                value={form.email}
                onChange={handleChange("email")}
                margin="normal"
                autoComplete="email"
                type="email"
                InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
                InputProps={{
                  sx: { color: "white", backgroundColor: inputFill, borderRadius: 2 },
                }}
              />

              <TextField
                fullWidth
                label="Phone"
                value={form.phone}
                onChange={handleChange("phone")}
                margin="normal"
                autoComplete="tel"
                InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
                InputProps={{
                  sx: { color: "white", backgroundColor: inputFill, borderRadius: 2 },
                }}
              />

              <TextField
                fullWidth
                label="Password"
                value={form.password}
                onChange={handleChange("password")}
                margin="normal"
                type={showPassword ? "text" : "password"}
                autoComplete="new-password"
                InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
                InputProps={{
                  sx: { color: "white", backgroundColor: inputFill, borderRadius: 2 },
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton
                        onClick={() => setShowPassword((s) => !s)}
                        edge="end"
                        sx={{ color: "rgba(255,255,255,0.8)" }}
                      >
                        {showPassword ? <VisibilityOff /> : <Visibility />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />

              <TextField
                fullWidth
                label="Admin Secret"
                value={form.adminSecret}
                onChange={handleChange("adminSecret")}
                margin="normal"
                type="password"
                autoComplete="off"
                helperText="This will be sent as x-admin-secret header"
                FormHelperTextProps={{ sx: { color: "rgba(255,255,255,0.55)" } }}
                InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
                InputProps={{
                  sx: { color: "white", backgroundColor: inputFill, borderRadius: 2 },
                }}
              />

              <Button
                type="submit"
                fullWidth
                disabled={!canSubmit || loading}
                sx={{
                  mt: 2,
                  py: 1.3,
                  borderRadius: 2,
                  fontWeight: 800,
                  backgroundColor: primaryButton,
                  color: "#0B1A15",
                  "&:hover": { backgroundColor: primaryButton, opacity: 0.9 },
                  "&.Mui-disabled": { opacity: 0.55, color: "#0B1A15" },
                }}
              >
                {loading ? (
                  <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                    <CircularProgress size={18} />
                    Creating...
                  </Box>
                ) : (
                  "Create Admin Account"
                )}
              </Button>

              <Typography sx={{ mt: 2, color: "rgba(255,255,255,0.55)", fontSize: 13 }}>
                After registration, you must verify email first.
              </Typography>
            </Box>
          )}
        </Paper>
      </Container>
    </Box>
  );
}
