//+------------------------------------------------------------------+
//|                                                        Robot.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://www.mql5.com"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== TAMPILAN GRAFIK ==="
input bool     InpShowDashboard     = true;     // Tampilkan Informasi di Grafik (Ya/Tidak)

input group "=== MODE TRANSAKSI WAKTU ==="
input bool     InpTimeTrading       = false;    // Transaksi Waktu (Default: Tidak)

input group "=== PENGATURAN LOT & MARTINGALE ==="
input double   InpLot               = 0.01;     // Lot Awal
input bool     InpEnableMartingale  = true;     // Aktif Martingler (Ya/Tidak)
input double   InpMultiplier        = 2.0;      // Pengali Martingale

input group "=== MODAL & EKUITAS ==="
input double   InpInitialCapital    = 1000.0;   // Modal
input double   InpMinEquity         = 800.0;    // Minimal Ekuitas (Stop Trading)
input double   InpStepProfit        = 10.0;     // Step Keuntungan (0 = Pengunci Non-Aktif)

input group "=== TARGET KEUNTUNGAN ==="
input double   InpProfitTransaction = 2.0;      // Keuntungan Transaksi (1 Posisi)
input double   InpTotalProfit       = 10.0;     // Keuntungan Total (Basket)
input double   InpStopProfit        = 0.0;      // Stop Profit (Ekuitas - Modal, 0 = Non-Aktif)

input group "=== JARAK & TRAILING STOP ==="
input int      InpDistancePoint     = 1000;     // Rentang (Point)
input bool     InpEnableTrailing    = true;     // Aktif Trailing (Ya/Tidak)
input int      InpTrailingStart     = 100;      // Trailing Start (Point)
input int      InpTrailingStep      = 100;      // Trailing Step (Point)

input group "=== LAIN-LAIN ==="
input ulong    InpMagicNumber       = 778899;   // Magic Number
input int      InpSlippage          = 10;       // Slippage

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade         m_trade;
CPositionInfo  m_position;

datetime       g_lastBarTime        = 0;
bool           g_tradingStopped     = false;
string         g_stopReason         = "";
bool           g_showDashboard      = true;

// Variabel Pengunci Keuntungan
double         g_highestEquity      = 0.0;
double         g_profitLockValue    = 0.0;
bool           g_lockActive         = false;

// Prefix nama objek visual di grafik
#define DASHBOARD_PREFIX "ROBOT_UI_"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetTypeFillingBySymbol(_Symbol);

   g_lastBarTime     = iTime(_Symbol, _Period, 0);
   g_highestEquity   = AccountInfoDouble(ACCOUNT_EQUITY);
   g_profitLockValue = 0.0;
   g_lockActive      = false;
   g_tradingStopped  = false;
   g_stopReason      = "";
   g_showDashboard   = InpShowDashboard;

   // Aktifkan timer 1 detik untuk menghitung waktu mundur candle & update grafik
   EventSetTimer(1);

   // Inisialisasi tampilan dashboard
   CreateDashboard();
   UpdateDashboard();

   Print("Robot EA MT5 Berhasil Diinisialisasi.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DestroyDashboard();
   Print("Robot EA MT5 Dimatikan.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Jalankan logika utama trading setiap tick
   ExecuteTradingLogic();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Timer function (1 detik)                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Perbarui tampilan waktu mundur dan metrik akun setiap detik
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Chart Event function (Klik tombol show/hide informasi)           |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == DASHBOARD_PREFIX + "BTN_TOGGLE")
      {
         g_showDashboard = !g_showDashboard;
         ObjectSetInteger(0, DASHBOARD_PREFIX + "BTN_TOGGLE", OBJPROP_STATE, false);
         
         if(g_showDashboard)
         {
            CreateDashboard();
            UpdateDashboard();
         }
         else
         {
            DestroyDashboardLabels();
            UpdateToggleButton();
            ChartRedraw(0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Normalize Lot Size sesuai aturan Broker                          |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;

   double normalized = MathFloor(lot / step) * step;
   if(normalized < minLot) normalized = minLot;
   if(normalized > maxLot) normalized = maxLot;

   int digits = 0;
   if(step == 0.01) digits = 2;
   else if(step == 0.1) digits = 1;
   else if(step == 0.001) digits = 3;

   return NormalizeDouble(normalized, digits);
}

//+------------------------------------------------------------------+
//| Logika Utama Trading                                             |
//+------------------------------------------------------------------+
void ExecuteTradingLogic()
{
   double currentEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // -------------------------------------------------------------
   // 1. CEK MINIMAL EKUITAS (PENGAMAN KERUGIAN)
   // -------------------------------------------------------------
   if(currentEquity <= InpMinEquity)
   {
      CloseAllPositions(-1);
      g_tradingStopped = true;
      g_stopReason = "STOP (MIN EKUITAS)";
      PrintFormat("PERINGATAN KRUSIAL: Ekuitas (%.2f) mencapai atau di bawah Minimal Ekuitas (%.2f). Semua posisi ditutup & robot berhenti permanen!",
                  currentEquity, InpMinEquity);
      return;
   }

   // -------------------------------------------------------------
   // 2. CEK STOP PROFIT (TARGET KEUNTUNGAN TOTAL DARI MODAL)
   // -------------------------------------------------------------
   // Jika diisi > 0: Ekuitas - Modal >= InpStopProfit -> Tutup SEMUA & Berhenti Trading Permanen
   // Jika diisi 0: Dianggap tidak berfungsi (non-aktif)
   if(InpStopProfit > 0.0)
   {
      double profitFromCapital = currentEquity - InpInitialCapital;
      if(profitFromCapital >= InpStopProfit)
      {
         CloseAllPositions(-1);
         g_tradingStopped = true;
         g_stopReason = "STOP (STOP PROFIT TERCAPAI)";
         PrintFormat("STOP PROFIT TERCAPAI: Ekuitas (%.2f) - Modal (%.2f) = %.2f >= Stop Profit (%.2f). Semua posisi ditutup & robot berhenti permanen!",
                     currentEquity, InpInitialCapital, profitFromCapital, InpStopProfit);
         return;
      }
   }

   if(g_tradingStopped)
   {
      return; // Tidak melakukan transaksi lagi
   }

   // -------------------------------------------------------------
   // 2. PROSES PENGUNCI KEUNTUNGAN (NON-AKTIF JIKA InpStepProfit <= 0)
   // -------------------------------------------------------------
   if(InpStepProfit > 0)
   {
      // Update rekor ekuitas tertinggi
      if(currentEquity > g_highestEquity)
      {
         g_highestEquity = currentEquity;

         // Pengunci aktif jika step keuntungan sudah mencapai minimal 2x step dari modal
         // Contoh: Modal 1000, Step 10 -> Aktif jika Ekuitas >= 1020
         if(g_highestEquity >= InpInitialCapital + (2.0 * InpStepProfit))
         {
            int stepsAbove = (int)MathFloor((g_highestEquity - InpInitialCapital) / InpStepProfit);
            // Ekuitas 1020 (step 2) -> Pengunci = 1000 + (2-1)*10 = 1010
            // Ekuitas 1030 (step 3) -> Pengunci = 1000 + (3-1)*10 = 1020
            // Ekuitas 1040 (step 4) -> Pengunci = 1000 + (4-1)*10 = 1030
            double newLockValue = InpInitialCapital + (double)(stepsAbove - 1) * InpStepProfit;
            if(newLockValue > g_profitLockValue)
            {
               g_profitLockValue = newLockValue;
               g_lockActive      = true;
               PrintFormat("Pengunci Keuntungan DITINGKATKAN ke: %.2f (Ekuitas Tertinggi: %.2f)", g_profitLockValue, g_highestEquity);
            }
         }
      }

      // Jika pengunci aktif dan ekuitas turun mencapai atau kurang dari nilai pengunci
      // Aturan:
      // - Pengunci TIDAK BISA dinonaktifkan jika masih ada transaksi berjalan.
      // - HANYA jika semua transaksi ditutup berdasarkan nilai pada pengunci, baru bisa NON-AKTIF kembali.
      if(g_lockActive && currentEquity <= g_profitLockValue)
      {
         PrintFormat("PENGUNCI KEUNTUNGAN TERCAPAI: Ekuitas (%.2f) <= Nilai Pengunci (%.2f). Menutup SEMUA transaksi!",
                     currentEquity, g_profitLockValue);
         
         // Tutup seluruh transaksi
         CloseAllPositions(-1);

         // Setelah semua transaksi ditutup karena menyentuh nilai pengunci, pengunci NON-AKTIF kembali
         g_lockActive      = false;
         g_profitLockValue = 0.0;
         g_highestEquity   = AccountInfoDouble(ACCOUNT_EQUITY); // Reset patokan ekuitas ke saldo/ekuitas saat ini
         Print("Semua transaksi telah ditutup berdasarkan nilai pengunci. Pengunci Keuntungan sekarang NON-AKTIF kembali.");
         return;
      }
   }
   else
   {
      // Jika diisi 0 atau negatif, pengunci selalu non-aktif
      g_lockActive      = false;
      g_profitLockValue = 0.0;
   }

   // -------------------------------------------------------------
   // 3. HITUNG DATA POSISI SAAT INI
   // -------------------------------------------------------------
   int      buyCount         = 0;
   int      sellCount        = 0;
   double   buyProfit        = 0.0;
   double   sellProfit       = 0.0;
   double   lowestBuyPrice   = DBL_MAX;
   double   highestSellPrice = 0.0;
   double   lastBuyLot       = InpLot;
   double   lastSellLot      = InpLot;
   datetime latestBuyTime    = 0;
   datetime latestSellTime   = 0;
   ulong    singleBuyTicket  = 0;
   ulong    singleSellTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long     type     = PositionGetInteger(POSITION_TYPE);
      double   profit   = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double   openPrice= PositionGetDouble(POSITION_PRICE_OPEN);
      double   vol      = PositionGetDouble(POSITION_VOLUME);
      datetime posTime  = (datetime)PositionGetInteger(POSITION_TIME);

      if(type == POSITION_TYPE_BUY)
      {
         buyCount++;
         buyProfit += profit;
         singleBuyTicket = ticket;
         if(openPrice < lowestBuyPrice) lowestBuyPrice = openPrice;
         if(posTime >= latestBuyTime)
         {
            latestBuyTime = posTime;
            lastBuyLot    = vol;
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         sellCount++;
         sellProfit += profit;
         singleSellTicket = ticket;
         if(openPrice > highestSellPrice) highestSellPrice = openPrice;
         if(posTime >= latestSellTime)
         {
            latestSellTime = posTime;
            lastSellLot    = vol;
         }
      }
   }

   double totalProfit = buyProfit + sellProfit;

   // -------------------------------------------------------------
   // 4. ATURAN PENUTUPAN TRANSAKSI (TAKE PROFIT & TOTAL PROFIT)
   // -------------------------------------------------------------
   if(InpTimeTrading)
   {
      // MODE TRANSAKSI WAKTU:
      // Penutupan transaksi dilakukan masing-masing (independen) jika sudah mencapai target total.
      // "misalnya transaksi buy sudah mencapai target total hanya buy saja yang tertutup, 
      //  jika misalnya sell belum mencapai target total, begitu juga untuk sell"

      // Cek apakah keranjang BUY sudah mencapai Target Keuntungan Total
      if(buyCount > 0 && buyProfit >= InpTotalProfit)
      {
         PrintFormat("Mode Transaksi Waktu: Target Keuntungan Total BUY Tercapai (%.2f >= %.2f). Menutup SEMUA posisi BUY saja!", buyProfit, InpTotalProfit);
         CloseAllPositions(POSITION_TYPE_BUY);
      }

      // Cek apakah keranjang SELL sudah mencapai Target Keuntungan Total
      if(sellCount > 0 && sellProfit >= InpTotalProfit)
      {
         PrintFormat("Mode Transaksi Waktu: Target Keuntungan Total SELL Tercapai (%.2f >= %.2f). Menutup SEMUA posisi SELL saja!", sellProfit, InpTotalProfit);
         CloseAllPositions(POSITION_TYPE_SELL);
      }
   }
   else
   {
      // LOGIKA STANDAR (LOGIKA LAMA):
      // PRIORITAS UTAMA: Target Keuntungan Total (Basket Global)
      // Jika total keuntungan seluruh posisi (Buy + Sell) mencapai keuntungan total, tutup SEMUA!
      if((buyCount > 0 || sellCount > 0) && totalProfit >= InpTotalProfit)
      {
         PrintFormat("Target Keuntungan Total Tercapai (%.2f >= %.2f). Menutup SEMUA posisi!", totalProfit, InpTotalProfit);
         CloseAllPositions(-1);
         return;
      }

      // ATURAN BUY:
      // "jika misalnya buy masih memiliki 1 transaksi dan jumlah keuntungan sudah mencapai keuntungan transaksi maka buy harus di tutup"
      if(buyCount == 1)
      {
         if(buyProfit >= InpProfitTransaction)
         {
            PrintFormat("Keuntungan Transaksi Buy Tercapai (%.2f >= %.2f). Menutup posisi Buy #%I64u!", buyProfit, InpProfitTransaction, singleBuyTicket);
            SafePositionClose(singleBuyTicket);
         }
         else if(InpEnableTrailing)
         {
            ApplyTrailingStop(singleBuyTicket, POSITION_TYPE_BUY);
         }
      }
      else if(buyCount > 1)
      {
         // Jika Buy memiliki lebih dari 1 transaksi, ditutup berdasarkan keuntungan total Buy
         if(buyProfit >= InpTotalProfit)
         {
            PrintFormat("Target Keuntungan Total Buy Tercapai (%.2f >= %.2f). Menutup SEMUA posisi Buy!", buyProfit, InpTotalProfit);
            CloseAllPositions(POSITION_TYPE_BUY);
         }
      }

      // ATURAN SELL:
      // Jika sell memiliki 1 transaksi dan keuntungan mencapai keuntungan transaksi, tutup sell
      if(sellCount == 1)
      {
         if(sellProfit >= InpProfitTransaction)
         {
            PrintFormat("Keuntungan Transaksi Sell Tercapai (%.2f >= %.2f). Menutup posisi Sell #%I64u!", sellProfit, InpProfitTransaction, singleSellTicket);
            SafePositionClose(singleSellTicket);
         }
         else if(InpEnableTrailing)
         {
            ApplyTrailingStop(singleSellTicket, POSITION_TYPE_SELL);
         }
      }
      else if(sellCount > 1)
      {
         // Jika Sell memiliki lebih dari 1 transaksi, ditutup berdasarkan keuntungan total Sell
         if(sellProfit >= InpTotalProfit)
         {
            PrintFormat("Target Keuntungan Total Sell Tercapai (%.2f >= %.2f). Menutup SEMUA posisi Sell!", sellProfit, InpTotalProfit);
            CloseAllPositions(POSITION_TYPE_SELL);
         }
      }
   }

   // -------------------------------------------------------------
   // 5 & 6. PEMBUKAAN TRANSAKSI (WAKTU VS LOGIKA LAMA)
   // -------------------------------------------------------------
   if(InpTimeTrading)
   {
      // MODE TRANSAKSI WAKTU:
      // Transaksi dilakukan SETIAP menyentuh angka waktu bernilai 0 (pergantian candle),
      // mengabaikan logika lama dengan langsung membuka BUY dan SELL sesuai Martingale.
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if(currentBarTime != g_lastBarTime)
      {
         g_lastBarTime = currentBarTime;

         // Hitung lot Martingale Buy
         double nextBuyLot = InpLot;
         if(buyCount > 0 && InpEnableMartingale)
            nextBuyLot = NormalizeLot(lastBuyLot * InpMultiplier);

         // Hitung lot Martingale Sell
         double nextSellLot = InpLot;
         if(sellCount > 0 && InpEnableMartingale)
            nextSellLot = NormalizeLot(lastSellLot * InpMultiplier);

         PrintFormat("Mode Transaksi Waktu (Waktu=0): Buka BUY (lot %.2f) dan SELL (lot %.2f)", nextBuyLot, nextSellLot);
         m_trade.Buy(nextBuyLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, "TimeTrade BUY");
         m_trade.Sell(nextSellLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, 0, "TimeTrade SELL");
      }
   }
   else
   {
      // -------------------------------------------------------------
      // LOGIKA LAMA: AVERAGING GRID / MARTINGALE BERDASARKAN RENTANG
      // -------------------------------------------------------------
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Logika Averaging Buy (jika rugi sebesar rentang dari buy terendah/terakhir)
      if(buyCount >= 1 && lowestBuyPrice < DBL_MAX)
      {
         double diffPoints = (lowestBuyPrice - currentAsk) / _Point;
         if(diffPoints >= InpDistancePoint)
         {
            double nextLot = InpLot;
            if(InpEnableMartingale)
               nextLot = NormalizeLot(lastBuyLot * InpMultiplier);

            PrintFormat("Rentang tercapai (%.1f pt >= %d pt). Buka BUY Martingale lot: %.2f", diffPoints, InpDistancePoint, nextLot);
            m_trade.Buy(nextLot, _Symbol, currentAsk, 0, 0, "Buy Martingale");
         }
      }

      // Logika Averaging Sell (jika rugi sebesar rentang dari sell tertinggi/terakhir)
      if(sellCount >= 1 && highestSellPrice > 0.0)
      {
         double diffPoints = (currentBid - highestSellPrice) / _Point;
         if(diffPoints >= InpDistancePoint)
         {
            double nextLot = InpLot;
            if(InpEnableMartingale)
               nextLot = NormalizeLot(lastSellLot * InpMultiplier);

            PrintFormat("Rentang tercapai (%.1f pt >= %d pt). Buka SELL Martingale lot: %.2f", diffPoints, InpDistancePoint, nextLot);
            m_trade.Sell(nextLot, _Symbol, currentBid, 0, 0, "Sell Martingale");
         }
      }

      // -------------------------------------------------------------
      // LOGIKA LAMA: TRANSAKSI BERDASARKAN WAKTU TIME FRAME SELEKTIF
      // -------------------------------------------------------------
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if(currentBarTime != g_lastBarTime)
      {
         g_lastBarTime = currentBarTime;

         if(buyCount == 0 && sellCount == 0)
         {
            Print("Waktu candle habis & posisi kosong. Buka BUY dan SELL secara bersamaan!");
            m_trade.Buy(InpLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, "Awal Candle Hedge BUY");
            m_trade.Sell(InpLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, 0, "Awal Candle Hedge SELL");
         }
         else if(buyCount > 0 && sellCount == 0)
         {
            Print("Waktu candle habis & ada posisi BUY. Buka SELL saja!");
            m_trade.Sell(InpLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, 0, "Candle Close SELL");
         }
         else if(sellCount > 0 && buyCount == 0)
         {
            Print("Waktu candle habis & ada posisi SELL. Buka BUY saja!");
            m_trade.Buy(InpLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, "Candle Close BUY");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop Logic                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, long posType)
{
   if(!m_position.SelectByTicket(ticket)) return;

   double openPrice = m_position.PriceOpen();
   double sl        = m_position.StopLoss();
   double pointVal  = _Point;

   if(posType == POSITION_TYPE_BUY)
   {
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double profitPoints = (currentBid - openPrice) / pointVal;

      if(profitPoints >= InpTrailingStart)
      {
         double newSL = NormalizeDouble(currentBid - (InpTrailingStep * pointVal), _Digits);
         if(newSL > sl + (pointVal * 5) && newSL > openPrice)
         {
            m_trade.PositionModify(ticket, newSL, m_position.TakeProfit());
         }
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profitPoints = (openPrice - currentAsk) / pointVal;

      if(profitPoints >= InpTrailingStart)
      {
         double newSL = NormalizeDouble(currentAsk + (InpTrailingStep * pointVal), _Digits);
         if((sl == 0.0 || newSL < sl - (pointVal * 5)) && newSL < openPrice)
         {
            m_trade.PositionModify(ticket, newSL, m_position.TakeProfit());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Tutup Posisi dengan Aman & Cek Error                             |
//+------------------------------------------------------------------+
bool SafePositionClose(ulong ticket)
{
   if(!m_position.SelectByTicket(ticket)) return false;
   bool res = m_trade.PositionClose(ticket, InpSlippage * 10);
   if(!res)
   {
      PrintFormat("Gagal menutup posisi #%I64u. Error code: %d", ticket, GetLastError());
   }
   return res;
}

//+------------------------------------------------------------------+
//| Tutup Semua Posisi (Filter: -1 semua, POSITION_TYPE_BUY/SELL)    |
//+------------------------------------------------------------------+
void CloseAllPositions(int filterType = -1)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(filterType == -1 || type == filterType)
      {
         SafePositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| FORMAT TAMPILAN DASHBOARD                                        |
//+------------------------------------------------------------------+
void UpdateToggleButton()
{
   string btnName = DASHBOARD_PREFIX + "BTN_TOGGLE";
   if(ObjectFind(0, btnName) < 0)
   {
      ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, 5);
      ObjectSetInteger(0, btnName, OBJPROP_XSIZE, 155);
      ObjectSetInteger(0, btnName, OBJPROP_YSIZE, 22);
      ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, btnName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
   }

   if(g_showDashboard)
   {
      ObjectSetString(0, btnName, OBJPROP_TEXT, "[-] Sembunyikan Info");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'35,45,60');
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, C'200,215,235');
   }
   else
   {
      ObjectSetString(0, btnName, OBJPROP_TEXT, "[+] Tampilkan Info");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, C'15,90,140');
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
   }
}

void CreateDashboard()
{
   // Tombol Toggle Show/Hide
   UpdateToggleButton();

   if(!g_showDashboard) return;

   // Background panel
   string bgName = DASHBOARD_PREFIX + "BG";
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 400);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 445);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,24,35');
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'50,60,80');
      ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   }

   // Label items (17 baris informasi)
   for(int i = 0; i < 17; i++)
   {
      string lblName = DASHBOARD_PREFIX + "LBL_" + IntegerToString(i);
      if(ObjectFind(0, lblName) < 0)
      {
         ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, 25);
         ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, 40 + (i * 24));
         ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      }
   }
}

void DestroyDashboardLabels()
{
   // Hapus background dan label saja, biarkan tombol toggle tetap ada
   string bgName = DASHBOARD_PREFIX + "BG";
   ObjectDelete(0, bgName);

   for(int i = 0; i < 17; i++)
   {
      string lblName = DASHBOARD_PREFIX + "LBL_" + IntegerToString(i);
      ObjectDelete(0, lblName);
   }
}

void DestroyDashboard()
{
   ObjectsDeleteAll(0, DASHBOARD_PREFIX);
}

void SetDashboardText(int lineIndex, string text, color clr = clrWhite, int fontSize = 9)
{
   if(!g_showDashboard) return;

   string lblName = DASHBOARD_PREFIX + "LBL_" + IntegerToString(lineIndex);
   ObjectSetString(0, lblName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, fontSize);
}

string GetTimeframeName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| Update Informasi di Grafik                                       |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   UpdateToggleButton();

   if(!g_showDashboard)
   {
      ChartRedraw(0);
      return;
   }

   // Hitung posisi
   int    buyCount   = 0;
   int    sellCount  = 0;
   double buyProfit  = 0.0;
   double sellProfit = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long   type   = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(type == POSITION_TYPE_BUY)
      {
         buyCount++;
         buyProfit += profit;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         sellCount++;
         sellProfit += profit;
      }
   }

   double totalProfit = buyProfit + sellProfit;
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);

   // Hitung waktu mundur candle
   datetime barTime      = iTime(_Symbol, _Period, 0);
   int      tfSeconds    = PeriodSeconds(_Period);
   datetime nextBarTime  = barTime + tfSeconds;
   datetime curTime      = TimeCurrent();
   int      diffSeconds  = (int)(nextBarTime - curTime);
   if(diffSeconds < 0) diffSeconds = 0;

   int hours   = diffSeconds / 3600;
   int minutes = (diffSeconds % 3600) / 60;
   int seconds = diffSeconds % 60;
   string countdownStr = StringFormat("%02d:%02d:%02d", hours, minutes, seconds);

   // Render tampilan baris per baris
   SetDashboardText(0, "== ROBOT TRADING MT5 ==", C'0,210,255', 10);
   string modeTrxStr = InpTimeTrading ? "Ya (Auto Hedge Martingale)" : "Tidak (Normal)";
   SetDashboardText(1, StringFormat("Trx Waktu: %s", modeTrxStr), (InpTimeTrading ? C'255,185,50' : C'190,200,215'));
   SetDashboardText(2, StringFormat("Input: Lot: %.2f | Marti: %s (x%.1f)", InpLot, (InpEnableMartingale?"Ya":"Tidak"), InpMultiplier), C'190,200,215');
   SetDashboardText(3, StringFormat("Modal: %.2f | Min Ekuitas: %.2f", InpInitialCapital, InpMinEquity), C'190,200,215');
   string stopProfitStr = (InpStopProfit > 0.0) ? StringFormat("%.2f", InpStopProfit) : "0 (Non-Aktif)";
   SetDashboardText(4, StringFormat("Trx TP: %.2f | Total TP: %.2f | Stop Profit: %s", InpProfitTransaction, InpTotalProfit, stopProfitStr), C'190,200,215');
   string stepStr = (InpStepProfit > 0) ? StringFormat("%.2f", InpStepProfit) : "0 (Non-Aktif)";
   SetDashboardText(5, StringFormat("Rentang: %d pt | Step Profit: %s", InpDistancePoint, stepStr), C'190,200,215');
   SetDashboardText(6, StringFormat("Trailing: %s (Start: %d, Step: %d pt)", (InpEnableTrailing?"Ya":"Tidak"), InpTrailingStart, InpTrailingStep), C'190,200,215');
   SetDashboardText(7, "--------------------------------------------------", C'70,80,100');

   // Info Akun & Posisi
   SetDashboardText(8, StringFormat("Saldo: $%.2f", balance), clrWhite);
   double profitFromModal = equity - InpInitialCapital;
   SetDashboardText(9, StringFormat("Ekuitas: $%.2f (Net: %+.2f)", equity, profitFromModal), (equity >= InpMinEquity ? C'120,240,150' : C'255,80,80'));
   
   string lockStatusStr = "NON-AKTIF";
   if(InpStepProfit <= 0)
      lockStatusStr = "NON-AKTIF (Input 0)";
   else if(g_lockActive)
      lockStatusStr = StringFormat("$%.2f (AKTIF)", g_profitLockValue);

   SetDashboardText(10, StringFormat("Pengunci Keuntungan: %s", lockStatusStr), (g_lockActive ? C'255,215,0' : C'160,160,170'));

   SetDashboardText(11, StringFormat("Jumlah Buy: %d", buyCount), C'130,190,255');
   SetDashboardText(12, StringFormat("Untung/Rugi Buy: $%.2f", buyProfit), (buyProfit >= 0 ? C'100,255,140' : C'255,100,100'));
   SetDashboardText(13, StringFormat("Jumlah Sell: %d", sellCount), C'255,170,120');
   SetDashboardText(14, StringFormat("Untung/Rugi Sell: $%.2f", sellProfit), (sellProfit >= 0 ? C'100,255,140' : C'255,100,100'));
   SetDashboardText(15, StringFormat("Jumlah Keuntungan Total: $%.2f", totalProfit), (totalProfit >= 0 ? C'50,255,130' : C'255,70,70'), 10);

   // Timeframe & Countdown
   string statusRobot = "BERJALAN";
   color  statusColor = C'100,255,140';
   if(g_tradingStopped)
   {
      statusRobot = (g_stopReason != "") ? g_stopReason : "STOPPED";
      statusColor = (g_stopReason == "STOP (STOP PROFIT TERCAPAI)") ? C'255,215,0' : C'255,60,60';
   }
   SetDashboardText(16, StringFormat("TF: %s | Waktu Mundur: %s | [%s]", GetTimeframeName((ENUM_TIMEFRAMES)_Period), countdownStr, statusRobot), statusColor);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
