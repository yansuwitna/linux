//+------------------------------------------------------------------+
//| Expert Advisor: EA_XAU_BollRSIMA                                |
//| Pair: XAUUSD | Timeframe: M15                                   |
//+------------------------------------------------------------------+
#property strict

// Input parameters
input double LotSize      = 0.01;
input int    StopLoss     = 70;       // in points
input int    TakeProfit   = 100;      // in points
input int    MAPeriod     = 50;
input int    BBPeriod     = 20;
input double BBDeviation  = 2.0;
input int    RSIPeriod    = 14;

// Tambah parameter input jumlah candle untuk hitung support dan demand
input int SupportDemandLookback = 50;

//+------------------------------------------------------------------+
int OnInit()
{
   Comment("✅ EA Initialized on ", _Symbol);
   EventSetTimer(1);    // Set timer 1 detik untuk update info
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();    // Hentikan timer saat EA dihapus
}

//+------------------------------------------------------------------+
// Update komentar info tiap detik pakai timer
void OnTimer()
{
   // Update info tanpa trading, hanya untuk komentar
   showInfo("⏳ Menunggu sinyal / posisi");
}

//+------------------------------------------------------------------+
// Logika trading dan gambar garis di OnTick (setiap tick baru)
void OnTick()
{
   static datetime lastCandleTime = 0;
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M15, 0);
   if (currentCandleTime == lastCandleTime)
       return;
   lastCandleTime = currentCandleTime;

   if (PositionsTotal() > 0)
   {
      showInfo("🔄 Menunggu posisi terbuka selesai...");
      DrawSupportDemandLines(); // Gambar garis support dan demand
      return;
   }

   double upperBB[], lowerBB[], rsi[], ma[];
   ArraySetAsSeries(upperBB, true);
   ArraySetAsSeries(lowerBB, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(ma, true);

   int bb = iBands(_Symbol, PERIOD_M15, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   CopyBuffer(bb, 1, 0, 2, upperBB);
   CopyBuffer(bb, 2, 0, 2, lowerBB);

   int rsi_handle = iRSI(_Symbol, PERIOD_M15, RSIPeriod, PRICE_CLOSE);
   CopyBuffer(rsi_handle, 0, 0, 2, rsi);

   int ma_handle = iMA(_Symbol, PERIOD_M15, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   CopyBuffer(ma_handle, 0, 0, 2, ma);

   double priceClose = iClose(_Symbol, PERIOD_M15, 1);

   string statusMsg = "⏳ Tidak ada sinyal valid";

   // Sinyal SELL
   if (priceClose < lowerBB[1] && rsi[1] < 50 && priceClose < ma[1])
   {
      statusMsg = "📉 Sinyal SELL terdeteksi";
      tradePosition(ORDER_TYPE_SELL);
   }
   // Sinyal BUY
   else if (priceClose > upperBB[1] && rsi[1] > 50 && priceClose > ma[1])
   {
      statusMsg = "📈 Sinyal BUY terdeteksi";
      tradePosition(ORDER_TYPE_BUY);
   }

   DrawSupportDemandLines();

   showInfo(statusMsg);
}

//+------------------------------------------------------------------+
// Fungsi mencari dan menggambar garis support dan demand
void DrawSupportDemandLines()
{
   if(ObjectFind(0, "SupportLine") != -1)
      ObjectDelete(0, "SupportLine");
   if(ObjectFind(0, "DemandLine") != -1)
      ObjectDelete(0, "DemandLine");

   double supportPrice = DBL_MAX;
   double demandPrice = 0.0;

   for(int i=1; i<=SupportDemandLookback; i++)
   {
      double low = iLow(_Symbol, PERIOD_M15, i);
      double high = iHigh(_Symbol, PERIOD_M15, i);

      if(low < supportPrice)
         supportPrice = low;
      if(high > demandPrice)
         demandPrice = high;
   }

   ObjectCreate(0, "SupportLine", OBJ_HLINE, 0, 0, supportPrice);
   ObjectSetInteger(0, "SupportLine", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, "SupportLine", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SupportLine", OBJPROP_TOOLTIP, "Support Level");

   ObjectCreate(0, "DemandLine", OBJ_HLINE, 0, 0, demandPrice);
   ObjectSetInteger(0, "DemandLine", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "DemandLine", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "DemandLine", OBJPROP_TOOLTIP, "Demand Level");
}

//+------------------------------------------------------------------+
// Fungsi buka posisi buy/sell
void tradePosition(ENUM_ORDER_TYPE orderType)
{
   double sl, tp, price;

   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - StopLoss * _Point;
      tp = price + TakeProfit * _Point;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + StopLoss * _Point;
      tp = price - TakeProfit * _Point;
   }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = LotSize;
   request.type     = orderType;
   request.price    = price;
   request.sl       = NormalizeDouble(sl, _Digits);
   request.tp       = NormalizeDouble(tp, _Digits);
   request.deviation= 10;
   request.magic    = 123456;
   request.comment  = "EA_XAU_BollRSIMA";

   if (!OrderSend(request, result))
      showInfo("❌ Gagal membuka posisi: " + IntegerToString(result.retcode));
   else
      showInfo("✅ Order berhasil: " + result.comment);
}

//+------------------------------------------------------------------+
// Tampilkan info + sisa waktu candle dalam menit:detik (update tiap 1 detik)
void showInfo(string status)
{
   int remaining = PeriodSeconds() - (int)(TimeCurrent() - iTime(_Symbol, _Period, 0));
   if(remaining < 0) remaining = 0;

   int minutes = remaining / 60;
   int seconds = remaining % 60;
   string remainingStr = StringFormat("%02d:%02d", minutes, seconds);

   double totalProfit = 0.0;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }

   string info = StringFormat(
      "🔹 %s (%s)\n" +
      "🕒 Time: %s\n" +
      "🕒 Bar Left: %s\n\n" +
      "📌 INPUT:\n" +
      "- LotSize: %.2f\n" +
      "- SL/TP: %d / %d\n" +
      "- MA: %d\n" +
      "- BB: %d (%.1f dev)\n" +
      "- RSI: %d\n\n" +
      "💰 ACCOUNT:\n" +
      "- Balance: %.2f\n" +
      "- Equity: %.2f\n" +
      "- Free Margin: %.2f\n" +
      "- Total Profit Posisi: %.2f\n\n" +
      "📡 STATUS:\n%s",
      _Symbol, EnumToString(_Period),
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
      remainingStr,
      LotSize, StopLoss, TakeProfit,
      MAPeriod, BBPeriod, BBDeviation, RSIPeriod,
      AccountInfoDouble(ACCOUNT_BALANCE),
      AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_FREEMARGIN),
      totalProfit,
      status
   );

   Comment(info);
}
