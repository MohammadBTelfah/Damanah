import React, { useEffect, useRef, useState } from "react";
import { Box, Container, Paper, Typography, Alert, CircularProgress } from "@mui/material";
import { useNavigate, useParams } from "react-router-dom";
import { adminVerifyEmail } from "../Service/AuthApi";

const bgColor = "#0F261F";

export default function AdminVerifyEmail() {
  const { token } = useParams();
  const navigate = useNavigate();
  const ranRef = useRef(false); // ✅ يمنع مرتين

  const [status, setStatus] = useState({ loading: true, ok: false, msg: "" });

  useEffect(() => {
    if (ranRef.current) return;       // ✅
    ranRef.current = true;            // ✅

    (async () => {
      try {
        const data = await adminVerifyEmail(token);

        setStatus({
          loading: false,
          ok: true,
          msg: data?.message || "Email verified successfully. Redirecting to login...",
        });

        setTimeout(() => navigate("/admin/login"), 1200);
      } catch (err) {
        const msg =
          err?.response?.data?.message ||
          err?.response?.data?.error ||
          err?.message ||
          "Verification failed";

        // ✅ إذا صار Invalid بعد ما تم التفعيل (بسبب الطلب الثاني) اعتبرها نجاح
        if (String(msg).toLowerCase().includes("invalid or expired")) {
          setStatus({
            loading: false,
            ok: true,
            msg: "Email already verified. Redirecting to login...",
          });
          setTimeout(() => navigate("/admin/login"), 1200);
          return;
        }

        setStatus({ loading: false, ok: false, msg });
      }
    })();
  }, [token, navigate]);

  return (
    <Box sx={{ minHeight: "100vh", backgroundColor: bgColor, display: "flex", alignItems: "center" }}>
      <Container maxWidth="sm">
        <Paper sx={{ p: 4, borderRadius: 3, backgroundColor: "rgba(255,255,255,0.04)" }}>
          <Typography variant="h5" sx={{ color: "white", fontWeight: 700, mb: 2 }}>
            Verifying email...
          </Typography>

          {status.loading ? (
            <Box sx={{ display: "flex", alignItems: "center", gap: 2, color: "white" }}>
              <CircularProgress size={22} />
              <Typography sx={{ color: "rgba(255,255,255,0.8)" }}>Please wait...</Typography>
            </Box>
          ) : status.ok ? (
            <Alert severity="success">{status.msg}</Alert>
          ) : (
            <Alert severity="error">{status.msg}</Alert>
          )}
        </Paper>
      </Container>
    </Box>
  );
}
