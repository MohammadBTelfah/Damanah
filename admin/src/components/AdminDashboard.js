import * as React from "react";
import PropTypes from "prop-types";
import Box from "@mui/material/Box";
import Typography from "@mui/material/Typography";
import { createTheme } from "@mui/material/styles";
import DashboardIcon from "@mui/icons-material/Dashboard";
import PersonIcon from "@mui/icons-material/Person";
import { AppProvider } from "@toolpad/core/AppProvider";
import { DashboardLayout } from "@toolpad/core/DashboardLayout";
import { DemoProvider, useDemoRouter } from "@toolpad/core/internal";
import GroupIcon from "@mui/icons-material/Group";
import BadgeIcon from "@mui/icons-material/Badge";
import FoundationIcon from '@mui/icons-material/Foundation';
import AssignmentLateIcon from "@mui/icons-material/AssignmentLate";
import CalculateIcon from '@mui/icons-material/Calculate';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';

import AdminLogin from "../components/AdminLogin";
import AdminProfile from "../components/AdminProfile";
import AdminUsersPage from "../components/AdminUsersPage";
import AdminIdentityPendingPage from "./AdminIdentityPendingPage"; // تأكد من المسارات
import AdminPendingContractorsPage from "./AdminPendingContractorsPage"; // تأكد من المسارات
import AdminDashboardHome from "../components/AdminDashboardHome";
import MaterialsPage from "../components/MaterialsPage";
import CostEstimator from "../components/CostEstimator";
import AdminInactiveUsersPage from "../components/AdminInactiveUsersPage";
const NAVIGATION = [
  {
    segment: "dashboard",
    title: "Dashboard",
    icon: <DashboardIcon />,
  },
  {
    segment: "profile",
    title: "Profile",
    icon: <PersonIcon />,
  },
  {
    segment: "users",
    title: "Users",
    icon: <GroupIcon />,
  },
  {
    segment: "identity-pending",
    title: "Pending Identities",
    icon: <BadgeIcon />,
  },
  {
    segment: "contractors-pending",
    title: "Pending Contractors",
    icon: <AssignmentLateIcon />,
  },
  {
    segment: "materials",
    title: "Materials",
    icon: <FoundationIcon />,
  },
  {
    segment: "cost-estimator",
    title: "Cost Estimator",
    icon: <CalculateIcon />,
  },
  {
    segment: "inactive-users",
    title: "Inactive Users",
    icon: <PersonIcon />,
  }
];

const demoTheme = createTheme({
  cssVariables: { colorSchemeSelector: "data-toolpad-color-scheme" },
  colorSchemes: { light: true, dark: true },
  breakpoints: { values: { xs: 0, sm: 600, md: 600, lg: 1200, xl: 1536 } },
});

function DemoPageContent({ pathname }) {
  return (
    <Box
      sx={{
        py: 4,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        textAlign: "center",
      }}
    >
      <Typography>Dashboard content for {pathname}</Typography>
    </Box>
  );
}
DemoPageContent.propTypes = { pathname: PropTypes.string.isRequired };

// ✅ التعديل الأول هنا: استقبال navigate وتمريرها
function PageSwitch({ pathname, navigate }) {
  if (pathname === "/dashboard") {
    // 👇 نمرر navigate هنا للصفحة الرئيسية
    return <AdminDashboardHome navigate={navigate} />;
  }
  if (pathname === "/profile") {
    return <AdminProfile />;
  }
  if (pathname === "/users") {
    return <AdminUsersPage />;
  }
  if (pathname === "/identity-pending") {
    return <AdminIdentityPendingPage />;
  }
  if (pathname === "/contractors-pending") {
    return <AdminPendingContractorsPage />;
  }
  if (pathname === "/materials") {
    return <MaterialsPage />;
  }
  if (pathname === "/cost-estimator") {
    return <CostEstimator />;
  }
  if (pathname === "/inactive-users") {
    return <AdminInactiveUsersPage />;
  }

  return <DemoPageContent pathname={pathname} />;
}

// ✅ إضافة navigate للـ propTypes
PageSwitch.propTypes = {
  pathname: PropTypes.string.isRequired,
  navigate: PropTypes.func.isRequired
};

const SESSION_KEY = "admin_session";

function loadSession(win) {
  try {
    const storage = win?.localStorage ?? localStorage;
    const raw = storage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveSession(win, session) {
  try {
    const storage = win?.localStorage ?? localStorage;
    if (session) storage.setItem(SESSION_KEY, JSON.stringify(session));
    else storage.removeItem(SESSION_KEY);
  } catch { }
}

export default function DashboardLayoutAccount(props) {
  const { window } = props;
  const router = useDemoRouter("/dashboard");
  const demoWindow = window !== undefined ? window() : undefined;

  const [session, setSession] = React.useState(() => loadSession(demoWindow));

  React.useEffect(() => {
    saveSession(demoWindow, session);
  }, [session, demoWindow]);

  const isLoginRoute = router.pathname === "/admin/login";

  React.useEffect(() => {
    if (!isLoginRoute && !session?.token) {
      router.navigate("/admin/login");
    }
  }, [isLoginRoute, session, router]);

  if (isLoginRoute) {
    return (
      <AdminLogin
        onLoggedIn={(nextSession) => {
          setSession(nextSession);
          router.navigate("/dashboard");
        }}
      />
    );
  }

  return (
    <DemoProvider window={demoWindow}>
      <AppProvider
        navigation={NAVIGATION}
        router={router}
        theme={demoTheme}
        window={demoWindow}
        session={session}
        authentication={{
          signOut: async () => {
            setSession(null);
            router.navigate("/admin/login");
          },
        }}
        branding={{
          logo: <AdminPanelSettingsIcon />, // أو يمكنك وضع صورة: <img src="logo.png" alt="logo" />
          title: "Damanah Admin",       // الاسم الذي تريده أن يظهر بدلاً من Toolpad
        }}

        localeText={{
          accountSignOutLabel: "Logout",
          accountSignInLabel: "Login",
        }}

      >
        <DashboardLayout>
          {/* ✅ التعديل الثاني هنا: تمرير router.navigate */}
          <PageSwitch pathname={router.pathname} navigate={router.navigate} />
        </DashboardLayout>
      </AppProvider>
    </DemoProvider>
  );
}

DashboardLayoutAccount.propTypes = { window: PropTypes.func };