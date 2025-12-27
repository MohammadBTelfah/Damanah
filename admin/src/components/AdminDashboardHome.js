import React from "react";
import SystemHealthCard from "./SystemHealthCard";

import {
  Box,
  Typography,
  CircularProgress,
  Alert,
  Divider,
  Chip,
  Paper,
} from "@mui/material";

import {
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as ReTooltip,
  Legend,
} from "recharts";

import {
  adminGetUsers,
  adminGetPendingIdentities,
  adminGetPendingContractors,
} from "../Service/AdminDashboardApi";

function CardShell({ children, sx }) {
  return (
    <Paper
      sx={{
        p: 3,
        borderRadius: 3,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid rgba(255,255,255,0.08)",
        boxShadow: "0 16px 40px rgba(0,0,0,0.35)",
        ...sx,
      }}
    >
      {children}
    </Paper>
  );
}

function StatRow({ title, value, sub }) {
  return (
    <CardShell
      sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}
    >
      <Box>
        <Typography sx={{ opacity: 0.8, fontWeight: 700 }}>{title}</Typography>
        {sub ? (
          <Typography sx={{ opacity: 0.55, mt: 0.3, fontSize: 13 }}>{sub}</Typography>
        ) : null}
      </Box>
      <Typography sx={{ fontSize: 36, fontWeight: 900, lineHeight: 1 }}>{value}</Typography>
    </CardShell>
  );
}

export default function AdminDashboardHome() {
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");

  const [totalUsers, setTotalUsers] = React.useState(0);
  const [clients, setClients] = React.useState(0);
  const [contractors, setContractors] = React.useState(0);
  const [admins, setAdmins] = React.useState(0);

  const [pendingIds, setPendingIds] = React.useState(0);
  const [pendingContractors, setPendingContractors] = React.useState(0);

  const load = React.useCallback(async () => {
    setError("");
    setLoading(true);
    try {
      const [all, ids, pendingCons] = await Promise.all([
        adminGetUsers(),
        adminGetPendingIdentities(),
        adminGetPendingContractors(),
      ]);

      const c = all.filter((u) => u.role === "client").length;
      const co = all.filter((u) => u.role === "contractor").length;
      const a = all.filter((u) => u.role === "admin").length;

      setTotalUsers(all.length);
      setClients(c);
      setContractors(co);
      setAdmins(a);

      setPendingIds(ids.length);
      setPendingContractors(pendingCons.length);
    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Failed to load dashboard");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    load();
  }, [load]);

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
        <CircularProgress />
      </Box>
    );
  }

  const rolePie = [
    { name: "Clients", value: clients },
    { name: "Contractors", value: contractors },
    { name: "Admins", value: admins },
  ];

  const pendingBars = [
    { name: "Pending Identities", value: pendingIds },
    { name: "Pending Contractors", value: pendingContractors },
  ];

  // ملاحظة: ما رح نحدد ألوان بشكل يدوي (بنخلي الافتراضي)
  const pieCells = ["#8884d8", "#82ca9d", "#ffc658"];

  return (
    <Box sx={{ px: { xs: 2, md: 4 }, py: 3, width: "100%" }}>
      <Box sx={{ mb: 2 }}>
        <Typography sx={{ fontSize: 34, fontWeight: 900, textAlign: "center" }}>
          Dashboard Overview
        </Typography>
      </Box>

      {error ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      ) : null}

      {/* نفس ستايل صفحاتك: rows كبيرة */}
      <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", lg: "1fr 1fr 1fr" }, gap: 2 }}>
        <StatRow title="Total Users" value={totalUsers} />
        <StatRow title="Pending Identities" value={pendingIds} sub="clients + contractors" />
        <StatRow title="Pending Contractors" value={pendingContractors} />
      </Box>

      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: { xs: "1fr", lg: "1.2fr 0.8fr" },
          gap: 2,
          mt: 2,
        }}
      >
        {/* Charts Card */}
        <CardShell>
          <Typography sx={{ fontWeight: 900, fontSize: 18, mb: 1 }}>Analytics</Typography>
          <Typography sx={{ opacity: 0.65, mb: 2, fontSize: 13 }}>
            Visual overview (roles + pending queues).
          </Typography>

          <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", md: "1fr 1fr" }, gap: 2 }}>
            {/* Pie */}
            <Box>
              <Typography sx={{ fontWeight: 800, mb: 1 }}>Roles distribution</Typography>
              <Box sx={{ height: 260 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={rolePie} dataKey="value" nameKey="name" outerRadius={90}>
                      {rolePie.map((_, idx) => (
                        <Cell key={idx} fill={pieCells[idx % pieCells.length]} />
                      ))}
                    </Pie>
                    <ReTooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </Box>
            </Box>

            {/* Bars */}
            <Box>
              <Typography sx={{ fontWeight: 800, mb: 1 }}>Pending queues</Typography>
              <Box sx={{ height: 260 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={pendingBars}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" hide />
                    <YAxis allowDecimals={false} />
                    <ReTooltip />
                    <Legend />
                    <Bar dataKey="value" name="Count" />
                  </BarChart>
                </ResponsiveContainer>
              </Box>

              <Box sx={{ display: "flex", gap: 1, flexWrap: "wrap", mt: 1 }}>
                <Chip label={`Clients: ${clients}`} />
                <Chip label={`Contractors: ${contractors}`} />
                <Chip label={`Admins: ${admins}`} />
              </Box>
            </Box>
          </Box>
        </CardShell>

        {/* Right card: نفس الشكل تماماً بس المحتوى صار real */}
        <CardShell>
          <SystemHealthCard />
        </CardShell>
      </Box>
    </Box>
  );
}
