import React from "react";
import { Box, Chip, Typography, Divider } from "@mui/material";
import { checkAuthHealth, checkAdminApisHealth, checkUploadsHealth } from "../Service/AdminHealthApi";

function StatusChip({ status }) {
  if (status === "loading") return <Chip label="..." size="small" />;
  if (status === "ok") return <Chip label="OK" size="small" color="success" />;
  return <Chip label="DOWN" size="small" color="error" />;
}

export default function SystemHealthCard() {
  const [state, setState] = React.useState({
    auth: "loading",
    admin: "loading",
    uploads: "loading",
  });

  const runChecks = React.useCallback(async () => {
    setState({ auth: "loading", admin: "loading", uploads: "loading" });

    const results = await Promise.allSettled([
      checkAuthHealth(),
      checkAdminApisHealth(),
      checkUploadsHealth(),
    ]);

    const ok = (r) =>
      r.status === "fulfilled" && (r.value?.ok === true || r.value?.ok === "true");

    setState({
      auth: ok(results[0]) ? "ok" : "down",
      admin: ok(results[1]) ? "ok" : "down",
      uploads: ok(results[2]) ? "ok" : "down",
    });
  }, []);

  React.useEffect(() => {
    runChecks();
    const id = setInterval(runChecks, 15000);
    return () => clearInterval(id);
  }, [runChecks]);

  return (
    <>
      <Typography sx={{ fontWeight: 900, fontSize: 18, mb: 1 }}>
        System Health
      </Typography>
      <Divider sx={{ opacity: 0.2, mb: 2 }} />

      <Box sx={{ display: "grid", gap: 1.2 }}>
        <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Typography sx={{ opacity: 0.75 }}>Auth</Typography>
          <StatusChip status={state.auth} />
        </Box>

        <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Typography sx={{ opacity: 0.75 }}>Admin APIs</Typography>
          <StatusChip status={state.admin} />
        </Box>

        <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Typography sx={{ opacity: 0.75 }}>Uploads</Typography>
          <StatusChip status={state.uploads} />
        </Box>
      </Box>

      <Typography sx={{ opacity: 0.6, fontSize: 13, mt: 2 }}>
        Auto-checks every 15s.
      </Typography>
    </>
  );
}
