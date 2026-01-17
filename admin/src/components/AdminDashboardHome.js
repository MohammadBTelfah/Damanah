import React, { useState, useEffect, useCallback } from "react";
import axios from "axios";
import {
  Box,
  Typography,
  CircularProgress,
  Alert,
  Paper,
  Button,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Divider,
  Grid,
  Container
} from "@mui/material";

import {
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as ReTooltip,
  Legend,
  AreaChart,
  Area
} from "recharts";

import {
  TrendingUp,
  TrendingDown,
  History,
  PersonAdd,
  Inventory2,
  Edit,
  Calculate,
  VerifiedUser
} from "@mui/icons-material";

import {
  adminGetUsers,
  adminGetPendingIdentities,
  adminGetPendingContractors,
} from "../Service/AdminDashboardApi";

// رابط API المواد (تأكد من البورت)
const MATERIALS_API_URL = "http://localhost:5000/api/materials";

// --- مكونات مساعدة (Sub-components) ---

function CardShell({ children, sx, title, sub }) {
  return (
    <Paper
      elevation={3}
      sx={{
        p: 3,
        borderRadius: 4,
        background: "rgba(30, 30, 30, 0.6)",
        backdropFilter: "blur(10px)",
        border: "1px solid rgba(255,255,255,0.08)",
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        ...sx,
      }}
    >
      {title && (
        <Box mb={2}>
          <Typography sx={{ fontWeight: 800, fontSize: 18, color: '#fff' }}>{title}</Typography>
          {sub && <Typography sx={{ opacity: 0.6, fontSize: 12, color: '#aaa' }}>{sub}</Typography>}
        </Box>
      )}
      {children}
    </Paper>
  );
}

function StatRow({ title, value, icon, trend }) {
  return (
    <CardShell sx={{ justifyContent: "center", alignItems: "flex-start" }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" width="100%">
        <Box>
          <Typography sx={{ opacity: 0.7, fontWeight: 600, fontSize: 14, mb: 0.5, color: '#ddd' }}>
            {title}
          </Typography>
          <Typography sx={{ fontSize: 32, fontWeight: 900, color: '#fff' }}>{value}</Typography>
        </Box>
        <Box sx={{ 
            p: 1.5, 
            borderRadius: "12px", 
            bgcolor: "rgba(144, 202, 249, 0.15)", 
            color: "#90caf9",
            display: 'flex'
        }}>
          {icon}
        </Box>
      </Box>
      {trend !== undefined && (
        <Box display="flex" alignItems="center" mt={2} gap={0.5}>
          {trend > 0 ? <TrendingUp color="success" sx={{ fontSize: 18 }} /> : <TrendingDown color="error" sx={{ fontSize: 18 }} />}
          <Typography variant="body2" sx={{ fontWeight: 'bold', color: trend > 0 ? "#66bb6a" : "#f44336" }}>
            {Math.abs(trend)}% from last week
          </Typography>
        </Box>
      )}
    </CardShell>
  );
}

const MarketTicker = ({ items }) => (
  <Box
    sx={{
      width: "100%",
      overflow: "hidden",
      bgcolor: "rgba(20, 20, 20, 0.8)",
      py: 1.5,
      mb: 4,
      borderRadius: 2,
      border: "1px solid rgba(255,255,255,0.1)",
      whiteSpace: "nowrap",
      position: "relative",
      boxShadow: "0 4px 12px rgba(0,0,0,0.2)"
    }}
  >
    <Box
      sx={{
        display: "inline-block",
        animation: "scroll 25s linear infinite",
        "@keyframes scroll": {
          "0%": { transform: "translateX(100%)" },
          "100%": { transform: "translateX(-100%)" },
        },
      }}
    >
      {items.map((item, index) => (
        <Typography
          key={index}
          component="span"
          sx={{ mx: 4, fontWeight: "600", fontSize: 15, color: "#e0e0e0" }}
        >
          {item.name}: <span style={{ color: "#90caf9", fontWeight: "bold" }}>{item.price} JOD</span>{" "}
          <span style={{ color: item.change >= 0 ? "#66bb6a" : "#f44336", fontSize: 13, marginLeft: 4 }}>
            ({item.change >= 0 ? "▲" : "▼"} {Math.abs(item.change)}%)
          </span>
        </Typography>
      ))}
    </Box>
  </Box>
);

// --- المكون الرئيسي ---

// ✅ نستقبل navigate هنا كـ prop بدلاً من استخدام هوك خارجي
export default function AdminDashboardHome({ navigate }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [stats, setStats] = useState({
    totalUsers: 0,
    totalMaterials: 0,
    pendingContractors: 0,
    steelPrice: 0
  });
  
  const [rolesData, setRolesData] = useState([]);
  const [priceTrendData, setPriceTrendData] = useState([]);
  
  const tickerItems = [
    { name: "Steel Rebar", price: stats.steelPrice || 540, change: 1.5 },
    { name: "Cement", price: 98, change: -0.5 },
    { name: "White Sand", price: 15, change: 0 },
    { name: "Hollow Block 15cm", price: 0.45, change: 2.1 },
  ];

  const recentActivities = [
    { text: "Admin Ahmad updated 'Steel' price", time: "10 mins ago", icon: <Edit fontSize="small" /> },
    { text: "New Contractor Request: Al-Amal Co.", time: "1 hour ago", icon: <PersonAdd fontSize="small" /> },
    { text: "System Backup Completed", time: "3 hours ago", icon: <History fontSize="small" /> },
    { text: "Deleted Material 'Old Ceramic'", time: "5 hours ago", icon: <Inventory2 fontSize="small" /> },
  ];

  const loadDashboard = useCallback(async () => {
    setError("");
    setLoading(true);
    try {
      const [users, , pendingCons] = await Promise.all([
        adminGetUsers(),
        adminGetPendingIdentities(),
        adminGetPendingContractors(),
      ]);

      let materials = [];
      let currentSteelPrice = 540;
      try {
        const matRes = await axios.get(MATERIALS_API_URL);
        materials = matRes.data;
        const steel = materials.find(m => m.name.toLowerCase().includes("steel") || m.name.includes("حديد"));
        if (steel && steel.variants.length > 0) {
            currentSteelPrice = steel.variants[0].pricePerUnit;
        }
      } catch (matErr) {
        console.warn("Using default material data");
      }

      setStats({
        totalUsers: users.length,
        totalMaterials: materials.length,
        pendingContractors: pendingCons.length,
        steelPrice: currentSteelPrice
      });

      const clients = users.filter((u) => u.role === "client").length;
      const contractors = users.filter((u) => u.role === "contractor").length;
      const admins = users.filter((u) => u.role === "admin").length;
      
      setRolesData([
        { name: "Clients", value: clients },
        { name: "Contractors", value: contractors },
        { name: "Admins", value: admins },
      ]);

      setPriceTrendData([
        { name: 'Jan', steel: 520, cement: 90 },
        { name: 'Feb', steel: 530, cement: 92 },
        { name: 'Mar', steel: 525, cement: 91 },
        { name: 'Apr', steel: 540, cement: 95 },
        { name: 'May', steel: 535, cement: 98 },
        { name: 'Jun', steel: currentSteelPrice, cement: 98 },
      ]);

    } catch (e) {
      setError(e?.response?.data?.message || e?.message || "Failed to load dashboard");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadDashboard();
  }, [loadDashboard]);

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", height: "80vh" }}>
        <CircularProgress size={60} />
      </Box>
    );
  }

  const pieColors = ["#8884d8", "#82ca9d", "#ffc658"];

  return (
    <Container maxWidth="xl" sx={{ py: 4 }}>
      
      <Box mb={3} textAlign="center">
        <Typography sx={{ fontSize: 32, fontWeight: 900, mb: 2, letterSpacing: 1 }}>
            Business Overview
        </Typography>
        <MarketTicker items={tickerItems} />
      </Box>

      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}

      {/* Grid container with center alignment */}
      <Grid container spacing={3} justifyContent="center">
        
        {/* Row 1: KPI Cards */}
        <Grid item xs={12} sm={6} md={3}>
            <StatRow 
                title="Total Users" 
                value={stats.totalUsers} 
                icon={<VerifiedUser />} 
                trend={5} 
            />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
            <StatRow 
                title="Total Materials" 
                value={stats.totalMaterials} 
                icon={<Inventory2 />} 
                trend={12} 
            />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
            <StatRow 
                title="Avg Steel Price" 
                value={`${stats.steelPrice} JOD`} 
                icon={<TrendingUp />} 
            />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
            <StatRow 
                title="Pending Contractors" 
                value={stats.pendingContractors} 
                icon={<PersonAdd />} 
                trend={stats.pendingContractors > 0 ? -stats.pendingContractors : 0}
            />
        </Grid>

        {/* Row 2: Charts & Activity */}
        <Grid item xs={12} lg={8}>
            <CardShell title="Market Price Trends (6 Months)">
                <Box height={320} width="100%">
                  <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={priceTrendData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                          <defs>
                              <linearGradient id="colorSteel" x1="0" y1="0" x2="0" y2="1">
                                  <stop offset="5%" stopColor="#8884d8" stopOpacity={0.8}/>
                                  <stop offset="95%" stopColor="#8884d8" stopOpacity={0}/>
                              </linearGradient>
                              <linearGradient id="colorCement" x1="0" y1="0" x2="0" y2="1">
                                  <stop offset="5%" stopColor="#82ca9d" stopOpacity={0.8}/>
                                  <stop offset="95%" stopColor="#82ca9d" stopOpacity={0}/>
                              </linearGradient>
                          </defs>
                          <XAxis dataKey="name" stroke="#777" />
                          <YAxis stroke="#777" />
                          <CartesianGrid strokeDasharray="3 3" stroke="#444" vertical={false} />
                          <ReTooltip 
                            contentStyle={{ backgroundColor: '#333', border: '1px solid #555', borderRadius: 8 }}
                            itemStyle={{ color: '#fff' }}
                          />
                          <Legend />
                          <Area type="monotone" dataKey="steel" stroke="#8884d8" strokeWidth={3} fillOpacity={1} fill="url(#colorSteel)" name="Steel Price" />
                          <Area type="monotone" dataKey="cement" stroke="#82ca9d" strokeWidth={3} fillOpacity={1} fill="url(#colorCement)" name="Cement Price" />
                      </AreaChart>
                  </ResponsiveContainer>
                </Box>
            </CardShell>
        </Grid>

        <Grid item xs={12} lg={4}>
            <CardShell title="Recent Activity">
                <List sx={{ width: '100%', bgcolor: 'transparent' }}>
                    {recentActivities.map((act, idx) => (
                        <React.Fragment key={idx}>
                            <ListItem alignItems="flex-start" sx={{ px: 0 }}>
                                <ListItemIcon sx={{ minWidth: 40, color: 'primary.main', mt: 0.5 }}>
                                    {act.icon}
                                </ListItemIcon>
                                <ListItemText
                                    primary={act.text}
                                    primaryTypographyProps={{ fontSize: 14, fontWeight: 500, color: '#eee' }}
                                    secondary={act.time}
                                    secondaryTypographyProps={{ fontSize: 12, color: 'gray' }}
                                />
                            </ListItem>
                            {idx < recentActivities.length - 1 && <Divider variant="inset" component="li" sx={{ ml: 6, borderColor: 'rgba(255,255,255,0.05)' }} />}
                        </React.Fragment>
                    ))}
                </List>
            </CardShell>
        </Grid>

        {/* Row 3: Secondary Info & Quick Actions */}
        <Grid item xs={12} md={4}>
             <CardShell title="User Distribution">
                <Box height={220}>
                    <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                            <Pie 
                              data={rolesData} 
                              dataKey="value" 
                              nameKey="name" 
                              outerRadius={70} 
                              innerRadius={40} 
                              label 
                            >
                                {rolesData.map((_, idx) => (
                                    <Cell key={idx} fill={pieColors[idx % pieColors.length]} />
                                ))}
                            </Pie>
                            <ReTooltip contentStyle={{ backgroundColor: '#333', borderRadius: 8 }} />
                            <Legend verticalAlign="bottom" height={36}/>
                        </PieChart>
                    </ResponsiveContainer>
                </Box>
             </CardShell>
        </Grid>

        <Grid item xs={12} md={8}>
            <CardShell title="Quick Actions">
                <Grid container spacing={3} sx={{ mt: 1 }}>
                    <Grid item xs={12} sm={4}>
                        <Button 
                          fullWidth 
                          variant="contained" 
                          color="primary" 
                          startIcon={<Inventory2 />} 
                          sx={{ height: 60, fontSize: '1.1rem', fontWeight: 'bold' }}
                          // ✅ استخدام الـ navigate الممررة
                          onClick={() => navigate('/materials')} 
                        >
                            Manage Materials
                        </Button>
                    </Grid>
                    <Grid item xs={12} sm={4}>
                        <Button 
                          fullWidth 
                          variant="outlined" 
                          color="secondary" 
                          startIcon={<Calculate />} 
                          sx={{ height: 60, fontSize: '1.1rem', fontWeight: 'bold', borderWidth: 2 }}
                          // ✅ استخدام الـ navigate الممررة
                          onClick={() => navigate('/cost-estimator')}
                        >
                            Cost Estimator
                        </Button>
                    </Grid>
                    <Grid item xs={12} sm={4}>
                        <Button 
                          fullWidth 
                          variant="outlined" 
                          color="warning" 
                          startIcon={<VerifiedUser />} 
                          sx={{ height: 60, fontSize: '1.1rem', fontWeight: 'bold', borderWidth: 2 }}
                          // ✅ استخدام الـ navigate الممررة (نفس الـ segment في NAVIGATION)
                          onClick={() => navigate('/contractors-pending')}
                        >
                            Verify Contractors
                        </Button>
                    </Grid>
                </Grid>
            </CardShell>
        </Grid>

      </Grid>
    </Container>
  );
}