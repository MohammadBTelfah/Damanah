import React, { useEffect, useMemo, useState } from "react";
import axios from "axios";
import {
  Box,
  Card,
  CardContent,
  Typography,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Button,
  Stack,
  Chip,
  CircularProgress,
  Alert,
} from "@mui/material";

const API_BASE = process.env.REACT_APP_API_BASE_URL || "http://localhost:5000";

// ✅ Read token from adminSession (localStorage)
function getAdminToken() {
  try {
    const raw = localStorage.getItem("adminSession"); // ✅ your key
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed?.token || null;
  } catch {
    return null;
  }
}

function authHeaders() {
  const token = getAdminToken();
  return {
    Authorization: token ? `Bearer ${token}` : "",
  };
}

export default function AdminInactiveUsersPage() {
  const [role, setRole] = useState("all"); // all | client | contractor | admin
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");

  const endpoint = useMemo(() => {
    if (role === "all") return `${API_BASE}/api/admin/users/inactive`;
    return `${API_BASE}/api/admin/users/inactive?role=${role}`;
  }, [role]);

  async function fetchInactive() {
    setError("");

    const token = getAdminToken();
    if (!token) {
      setRows([]);
      setError("Admin token not found. Please login as admin again.");
      return;
    }

    setLoading(true);
    try {
      const res = await axios.get(endpoint, { headers: authHeaders() });
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchInactive();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [endpoint]);

  async function activateUser(u) {
    setError("");
    setBusyId(u._id);
    try {
      await axios.patch(
        `${API_BASE}/api/admin/users/${u.role}/${u._id}/activate`,
        {},
        { headers: authHeaders() }
      );

      // ✅ الأفضل: Refresh من السيرفر بعد التفعيل
      await fetchInactive();
    } catch (e) {
      setError(e?.response?.data?.message || e?.response?.data?.error || e.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <Box sx={{ p: 3 }}>
      <Card sx={{ borderRadius: 3 }}>
        <CardContent>
          <Stack
            direction={{ xs: "column", sm: "row" }}
            alignItems={{ sm: "center" }}
            justifyContent="space-between"
            spacing={2}
            sx={{ mb: 2 }}
          >
            <Box>
              <Typography variant="h5" fontWeight={800}>
                Inactive Accounts
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Review accounts that are currently inactive and activate them.
              </Typography>
            </Box>

            <Stack direction="row" spacing={2} alignItems="center">
              <FormControl size="small" sx={{ minWidth: 180 }}>
                <InputLabel>Role</InputLabel>
                <Select value={role} label="Role" onChange={(e) => setRole(e.target.value)}>
                  <MenuItem value="all">All</MenuItem>
                  <MenuItem value="client">Client</MenuItem>
                  <MenuItem value="contractor">Contractor</MenuItem>
                  <MenuItem value="admin">Admin</MenuItem>
                </Select>
              </FormControl>

              <Button variant="outlined" onClick={fetchInactive} disabled={loading}>
                Refresh
              </Button>
            </Stack>
          </Stack>

          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          {loading ? (
            <Box sx={{ py: 6, display: "flex", justifyContent: "center" }}>
              <CircularProgress />
            </Box>
          ) : (
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Name</TableCell>
                  <TableCell>Email</TableCell>
                  <TableCell>Role</TableCell>
                  <TableCell>Verified Email</TableCell>
                  <TableCell align="right">Action</TableCell>
                </TableRow>
              </TableHead>

              <TableBody>
                {rows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5}>
                      <Typography color="text.secondary">
                        No inactive accounts found.
                      </Typography>
                    </TableCell>
                  </TableRow>
                ) : (
                  rows.map((u) => (
                    <TableRow key={u._id} hover>
                      <TableCell sx={{ fontWeight: 700 }}>{u.name || "-"}</TableCell>
                      <TableCell>{u.email || "-"}</TableCell>
                      <TableCell>
                        <Chip size="small" label={u.role} variant="outlined" />
                      </TableCell>
                      <TableCell>
                        {typeof u.emailVerified === "boolean" ? (u.emailVerified ? "Yes" : "No") : "-"}
                      </TableCell>
                      <TableCell align="right">
                        <Button
                          variant="contained"
                          onClick={() => activateUser(u)}
                          disabled={busyId === u._id}
                        >
                          {busyId === u._id ? "Activating..." : "Activate"}
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}
