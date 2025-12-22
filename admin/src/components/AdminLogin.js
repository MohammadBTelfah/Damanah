import React, { useMemo, useState } from "react";
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
} from "@mui/material";
import Visibility from "@mui/icons-material/Visibility";
import VisibilityOff from "@mui/icons-material/VisibilityOff";
import { useNavigate } from "react-router-dom";
import { adminLogin, adminResendVerification } from "../Service/AuthApi";

// 🎨 Colors
const bgColor = "#0F261F";
const inputFill = "#1B3A35";
const primaryButton = "#8BE3B5";

export default function AdminLogin() {
  const navigate = useNavigate();

  const [form, setForm] = useState({
    email: "",
    password: "",
  });

  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");

  const [canResend, setCanResend] = useState(false);

  const canSubmit = useMemo(() => {
    return form.email.trim() && form.password.trim();
  }, [form]);

  const handleChange = (key) => (e) => {
    setForm((prev) => ({ ...prev, [key]: e.target.value }));
  };

  const normalizeError = (err) => {
    const msg =
      err?.response?.data?.message ||
      err?.response?.data?.error ||
      err?.message ||
      "Something went wrong";
    return msg;
  };

  const saveSession = (data) => {
    // ✅ Keep it simple. You can swap to localStorage if you want persistence.
    const token = data?.token || "";
    const user = data?.user || null;
    const role = data?.role || "admin";

    sessionStorage.setItem("token", token);
    sessionStorage.setItem("role", role);
    sessionStorage.setItem("user", JSON.stringify(user));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg("");
    setSuccessMsg("");
    setCanResend(false);

    if (!canSubmit) {
      setErrorMsg("Please enter email and password.");
      return;
    }

    setLoading(true);
    try {
      const data = await adminLogin({
        email: form.email.trim(),
        password: form.password,
      });

      saveSession(data);
      setSuccessMsg("Logged in successfully. Redirecting...");

      setTimeout(() => navigate("/"), 600);
    } catch (err) {
      const msg = normalizeError(err);
      setErrorMsg(msg);

      // ✅ If backend says verify email, show resend button
      if (msg.toLowerCase().includes("verify your email")) {
        setCanResend(true);
      }
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
      setCanResend(false);
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
            Admin Login
          </Typography>
          <Typography sx={{ color: "rgba(255,255,255,0.7)", mb: 3 }}>
            Sign in to your admin dashboard.
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

          <Box component="form" onSubmit={handleSubmit}>
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
                sx: {
                  color: "white",
                  backgroundColor: inputFill,
                  borderRadius: 2,
                },
              }}
            />

            <TextField
              fullWidth
              label="Password"
              value={form.password}
              onChange={handleChange("password")}
              margin="normal"
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              InputLabelProps={{ sx: { color: "rgba(255,255,255,0.7)" } }}
              InputProps={{
                sx: {
                  color: "white",
                  backgroundColor: inputFill,
                  borderRadius: 2,
                },
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

            <Button
              type="submit"
              fullWidth
              disabled={!canSubmit || loading}
              sx={{
                mt: 2,
                py: 1.3,
                borderRadius: 2,
                fontWeight: 900,
                backgroundColor: primaryButton,
                color: "#0B1A15",
                "&:hover": { backgroundColor: primaryButton, opacity: 0.9 },
                "&.Mui-disabled": { opacity: 0.55, color: "#0B1A15" },
              }}
            >
              {loading ? (
                <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                  <CircularProgress size={18} />
                  Signing in...
                </Box>
              ) : (
                "Login"
              )}
            </Button>

            {canResend ? (
              <Button
                fullWidth
                onClick={handleResend}
                disabled={loading || !form.email.trim()}
                sx={{
                  mt: 1.2,
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
            ) : null}

            <Typography sx={{ mt: 2, color: "rgba(255,255,255,0.55)", fontSize: 13 }}>
              If you just verified your email, refresh and try login again.
            </Typography>
          </Box>
        </Paper>
      </Container>
    </Box>
  );
}
