--------------------------------------------------
-- TẠO DATABASE
--------------------------------------------------
CREATE DATABASE QLRP_CGV_65131636;
GO
USE QLRP_CGV_65131636;
GO

--------------------------------------------------
-- BẢNG PHÂN QUYỀN – TÀI KHOẢN
--------------------------------------------------
CREATE TABLE PhanQuyen(
    MaQuyen INT PRIMARY KEY,
    TenQuyen NVARCHAR(50)
);

CREATE TABLE TaiKhoan(
    Email VARCHAR(100) PRIMARY KEY, 
    MatKhau VARCHAR(100),
    MaQuyen INT FOREIGN KEY REFERENCES PhanQuyen(MaQuyen)
);

--------------------------------------------------
-- BẢNG KHÁCH HÀNG
--------------------------------------------------
CREATE TABLE KhachHang(
    MaKH INT IDENTITY PRIMARY KEY,
    HoTen NVARCHAR(100),
    NgaySinh DATE,
	SDT VARCHAR(15),
    Email VARCHAR(100) FOREIGN KEY REFERENCES TaiKhoan(Email)
    
);
--------------------------------------------------
-- BẢNG THỂ LOẠI
--------------------------------------------------
CREATE TABLE TheLoai(
    MaTL INT IDENTITY PRIMARY KEY,
    TenTL NVARCHAR(50) UNIQUE -- Tên thể loại (Ví dụ: 'Hành động', 'Hoạt hình', 'Viễn tưởng')
);
--------------------------------------------------
-- BẢNG PHIM
--------------------------------------------------
CREATE TABLE Phim(
    MaPhim INT IDENTITY PRIMARY KEY,
    TenPhim NVARCHAR(200),
	TomTat NVARCHAR(MAX),
    ThoiLuong INT,
    DoTuoiYeuCau INT,	
	AnhPhim VARCHAR(255)
);
--------------------------------------------------
-- BẢNG PHIM THỂ LOẠI
--------------------------------------------------
CREATE TABLE Phim_TheLoai(
    MaPhim INT FOREIGN KEY REFERENCES Phim(MaPhim),
    MaTL INT FOREIGN KEY REFERENCES TheLoai(MaTL),
    -- Khóa chính kép đảm bảo mỗi cặp Phim-Thể loại là duy nhất
    PRIMARY KEY (MaPhim, MaTL)
);
--------------------------------------------------
-- BẢNG PHÒNG
--------------------------------------------------
CREATE TABLE Phong(
    MaPhong INT IDENTITY PRIMARY KEY,
    TenPhong NVARCHAR(50),
    SoCho INT
);

--------------------------------------------------
-- BẢNG GHẾ
--------------------------------------------------
CREATE TABLE Ghe(
    MaGhe INT IDENTITY PRIMARY KEY,
    MaPhong INT FOREIGN KEY REFERENCES Phong(MaPhong),
    ViTri NVARCHAR(10)
);

--------------------------------------------------
-- BẢNG SUẤT CHIẾU
--------------------------------------------------
CREATE TABLE SuatChieu(
    MaSC INT IDENTITY PRIMARY KEY,
    MaPhim INT FOREIGN KEY REFERENCES Phim(MaPhim),
    MaPhong INT FOREIGN KEY REFERENCES Phong(MaPhong),
    NgayChieu DATE,
    GioChieu TIME,
    GiaVe DECIMAL(10,2)
);

--------------------------------------------------
-- ĐẶT VÉ + VÉ
--------------------------------------------------
CREATE TABLE DatVe(
    MaDatVe INT IDENTITY PRIMARY KEY,
    MaKH INT FOREIGN KEY REFERENCES KhachHang(MaKH),
    MaSC INT FOREIGN KEY REFERENCES SuatChieu(MaSC),
	TrangThai INT DEFAULT 0,
    NgayDat DATETIME DEFAULT GETDATE()
);

CREATE TABLE Ve(
    MaVe INT IDENTITY PRIMARY KEY,
    MaDatVe INT FOREIGN KEY REFERENCES DatVe(MaDatVe),
    MaGhe INT FOREIGN KEY REFERENCES Ghe(MaGhe),
    GiaVe DECIMAL(10,2)
);

--------------------------------------------------
-- DỊCH VỤ
--------------------------------------------------
CREATE TABLE DichVu(
    MaDV INT IDENTITY PRIMARY KEY,
    TenDV NVARCHAR(100),
    Gia DECIMAL(10,2)
);

CREATE TABLE HoaDonDichVu(
    MaHDDV INT IDENTITY PRIMARY KEY,
    MaKH INT FOREIGN KEY REFERENCES KhachHang(MaKH),
    MaDV INT FOREIGN KEY REFERENCES DichVu(MaDV),
	MaDatVe INT,
    SoLuong INT,
    NgayMua DATETIME DEFAULT GETDATE(),
	--ON DELETE CASCADE giúp xóa Đơn vé thì Dịch vụ đi kèm tự mất luôn
	CONSTRAINT FK_HoaDonDichVu_DatVe FOREIGN KEY (MaDatVe) REFERENCES DatVe(MaDatVe) ON DELETE CASCADE
);

--------------------------------------------------
-- KHUYẾN MÃI (HS + SV)
--------------------------------------------------
CREATE TABLE KhuyenMai(
    MaKM INT IDENTITY PRIMARY KEY,
    TenKM NVARCHAR(100),
    DoiTuong NVARCHAR(50),
    TiLeGiam DECIMAL(5,2)
);

--------------------------------------------------
-- FUNCTION KIỂM TRA TUỔI
--------------------------------------------------
GO

CREATE FUNCTION dbo.KiemTraDoTuoi
(
    @NgaySinh DATE, 
    @YeuCau INT
)
RETURNS BIT
AS
BEGIN
    -- Nếu không có ngày sinh (NULL) -> Coi như không đủ tuổi
    IF @NgaySinh IS NULL RETURN 0;

    -- Tính tuổi chính xác theo ngày tháng
    DECLARE @Tuoi INT;
    SET @Tuoi = DATEDIFF(YEAR, @NgaySinh, GETDATE()) - 
                CASE 
                    WHEN (MONTH(@NgaySinh) > MONTH(GETDATE())) OR 
                         (MONTH(@NgaySinh) = MONTH(GETDATE()) AND DAY(@NgaySinh) > DAY(GETDATE())) 
                    THEN 1 
                    ELSE 0 
                END;

    IF (@Tuoi >= @YeuCau)
        RETURN 1; -- Đủ tuổi
    
    RETURN 0; -- Không đủ tuổi
END;
GO
--------------------------------------------------
-- FUNCTION TÍNH GIẢM GIÁ
-- Trẻ dưới 6 tuổi miễn phí vé
--------------------------------------------------
CREATE FUNCTION dbo.TinhGiamGia(@NgaySinh DATE)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Tuoi INT = DATEDIFF(YEAR, @NgaySinh, GETDATE());
    DECLARE @LoaiKH_TinhToan NVARCHAR(50);
    DECLARE @Giam DECIMAL(5,2);

    -- Quy tắc xác định loại khách hàng dựa trên tuổi
    IF (@Tuoi < 6)
        SET @LoaiKH_TinhToan = 'TreEmDuoi6';
    ELSE IF (@Tuoi >= 6 AND @Tuoi <= 17) -- Ví dụ: Học sinh (6-17 tuổi)
        SET @LoaiKH_TinhToan = 'HocSinh';
    ELSE IF (@Tuoi >= 18 AND @Tuoi <= 22) -- Ví dụ: Sinh viên (18-22 tuổi)
        SET @LoaiKH_TinhToan = 'SinhVien';
    ELSE
        SET @LoaiKH_TinhToan = 'NguoiLon';

    -- Xử lý giảm giá
    IF (@LoaiKH_TinhToan = 'TreEmDuoi6')
        RETURN 1.00; -- Giảm 100% (miễn phí)

    SELECT @Giam = TiLeGiam
    FROM KhuyenMai
    WHERE DoiTuong = @LoaiKH_TinhToan;

    RETURN ISNULL(@Giam, 0);
END;
GO
--------------------------------------------------
-- PROCEDURE ĐĂNG KÝ THÀNH VIÊN
--------------------------------------------------
CREATE PROCEDURE DangKyThanhVien
    @Email VARCHAR(100),
    @MatKhau VARCHAR(100),
    @HoTen NVARCHAR(100),
    @NgaySinh DATE,
    @SDT VARCHAR(15),
    @Result NVARCHAR(200) OUTPUT
AS
BEGIN
    -- 1. Kiểm tra Email đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM TaiKhoan WHERE Email = @Email)
    BEGIN
        SET @Result = N'Email này đã được đăng ký!';
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 2. Tạo Tài Khoản (Quyền 3 = Khách hàng)
        INSERT INTO TaiKhoan(Email, MatKhau, MaQuyen)
        VALUES (@Email, @MatKhau, 3);

        -- 3. Tạo Thông Tin Khách Hàng (Tự động lấy Email vừa tạo để liên kết)
        INSERT INTO KhachHang(HoTen, NgaySinh, SDT, Email)
        VALUES (@HoTen, @NgaySinh, @SDT, @Email);

        COMMIT TRANSACTION;
        SET @Result = N'Đăng ký thành công!';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @Result = N'Lỗi: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
--------------------------------------------------
-- PROCEDURE TÌM KIẾM PHIM
--------------------------------------------------
GO
CREATE PROCEDURE TimKiemPhim
    @TuKhoa NVARCHAR(100)
AS
BEGIN
    -- Lấy MaPhim DISTINCT từ 3 điều kiện tìm kiếm:
    -- 1. Theo Tên Phim
    -- 2. Theo Thể loại
    -- 3. Theo Mã Phim
    SELECT DISTINCT P.*
    FROM Phim P
    -- LEFT JOIN để lấy được cả phim không có thể loại 
    LEFT JOIN Phim_TheLoai PTL ON P.MaPhim = PTL.MaPhim
    LEFT JOIN TheLoai TL ON PTL.MaTL = TL.MaTL
    WHERE P.TenPhim LIKE N'%' + @TuKhoa + N'%' -- Tìm kiếm theo Tên Phim
       OR TL.TenTL LIKE N'%' + @TuKhoa + N'%' -- **Tìm kiếm theo Tên Thể Loại**
	   OR CAST(P.MaPhim AS NVARCHAR(10)) = @TuKhoa;  
END;
GO

------------------------------------------------------------------------------------------------------------------
-- 1. Thủ tục lấy danh sách vé của Mã Đặt Vé
CREATE PROCEDURE Sp_LayChiTietVe_65131636
    @MaDatVe INT
AS
BEGIN
    SELECT 
        G.ViTri AS TenGhe,
        V.GiaVe
    FROM Ve V
    JOIN Ghe G ON V.MaGhe = G.MaGhe
    WHERE V.MaDatVe = @MaDatVe;
END;
GO

-- 2. Thủ tục lấy danh sách dịch vụ (bắp nước) của khách hàng trong ngày đó
CREATE PROCEDURE Sp_LayChiTietDichVu_65131636
    @MaDatVe INT
AS
BEGIN
    DECLARE @MaKH INT;
    DECLARE @NgayDat DATE;

    -- Lấy thông tin khách hàng và ngày đặt từ bảng DatVe
    SELECT @MaKH = MaKH, @NgayDat = CAST(NgayDat AS DATE) 
    FROM DatVe WHERE MaDatVe = @MaDatVe;

    -- Lấy dịch vụ khách mua cùng ngày
    SELECT 
        DV.TenDV,
        HD.SoLuong,
        DV.Gia,
        (HD.SoLuong * DV.Gia) AS ThanhTien
    FROM HoaDonDichVu HD
    JOIN DichVu DV ON HD.MaDV = DV.MaDV
    WHERE HD.MaKH = @MaKH 
    AND CAST(HD.NgayMua AS DATE) = @NgayDat;
END;
GO

-- 3. Thủ tục lấy thông tin chung (Header hóa đơn)
CREATE PROCEDURE Sp_ThongTinHoaDon_65131636
    @MaDatVe INT
AS
BEGIN
    SELECT 
        KH.HoTen AS HoTenKH,
        KH.SDT,
        P.TenPhim,
        SC.NgayChieu,
        SC.GioChieu,
        Ph.TenPhong,
        DV.NgayDat
    FROM DatVe DV
    JOIN KhachHang KH ON DV.MaKH = KH.MaKH
    JOIN SuatChieu SC ON DV.MaSC = SC.MaSC
    JOIN Phim P ON SC.MaPhim = P.MaPhim
    JOIN Phong Ph ON SC.MaPhong = Ph.MaPhong
    WHERE DV.MaDatVe = @MaDatVe;
END;
GO
------------------------------------------------------------------------------------------------------------------
--------------------------------------------------
-- DỮ LIỆU MẪU NĂM 2025
--------------------------------------------------

-- PHÂN QUYỀN
INSERT INTO PhanQuyen VALUES
(1, 'Admin'),
(2, 'NhanVien'),
(3, 'KhachHang');

-- TÀI KHOẢN
INSERT INTO TaiKhoan(Email, MatKhau, MaQuyen) VALUES
('admin@cgv.vn', '123', 1),
('nhanvien@cgv.vn', '123', 2),
-- Tài khoản khách hàng dùng để test đăng nhập
('hocsinh@gmail.com', '123', 3), 
('sinhvien@gmail.com', '123', 3),
('nguoilon@gmail.com', '123', 3);

-- KHÁCH HÀNG 
INSERT INTO KhachHang(HoTen, NgaySinh, SDT, Email) VALUES
(N'Nguyễn Văn A', '2010-05-01', '0901111111', 'hocsinh@gmail.com'),
(N'Trần Thị B', '2004-03-20', '0902222222', 'sinhvien@gmail.com'),
(N'Lê Văn C', '1990-09-10', '0903333333', 'nguoilon@gmail.com');

-- THỂ LOẠI 
INSERT INTO TheLoai (TenTL) VALUES
(N'Hành động'),    -- MaTL = 1
(N'Hoạt hình'),    -- MaTL = 2
(N'Viễn tưởng'),   -- MaTL = 3
(N'Hài hước'),     -- MaTL = 4
(N'Phiêu lưu');    -- MaTL = 5

-- PHIM 
INSERT INTO Phim(TenPhim, TomTat, ThoiLuong, DoTuoiYeuCau, AnhPhim) VALUES
(N'Deadpool & Wolverine', N'Hai dị nhân đối lập Deadpool và Wolverine bị kéo vào một nhiệm vụ bí ẩn bởi tổ chức TVA, buộc họ phải hợp tác để cứu lấy đa vũ trụ. Bộ phim đánh dấu sự tái xuất của Wolverine trong MCU.', 128, 18,'deadpool_wolverine.jpg'), -- MaPhim = 1
(N'Doraemon: Nobita và Vùng Đất Mới', N'Nobita và những người bạn tình cờ tìm thấy một vùng đất bí ẩn chưa được khám phá, nơi họ phải đối mặt với nhiều thử thách và hiểm nguy để bảo vệ những cư dân nơi đây.', 96, 0,'doraemon.jpg'), -- MaPhim = 2
(N'Avengers: Secret Wars', N'Phim đỉnh cao khép lại Saga Đa vũ trụ, nơi các anh hùng từ khắp các thực tại phải hợp sức để chiến đấu trong một cuộc chiến sinh tồn chống lại mối đe dọa toàn vũ trụ.', 150, 13,'avengers_secret_wars.jpg'); -- MaPhim = 3

-- THIẾT LẬP MỐI QUAN HỆ PHIM - THỂ LOẠI 
-- Phim 1 (Deadpool) thuộc Hành động (1), Hài hước (4)
INSERT INTO Phim_TheLoai (MaPhim, MaTL) VALUES
(1, 1), -- Hành động
(1, 4); -- Hài hước

-- Phim 2 (Doraemon) thuộc Hoạt hình (2), Phiêu lưu (5)
INSERT INTO Phim_TheLoai (MaPhim, MaTL) VALUES
(2, 2), -- Hoạt hình
(2, 5); -- Phiêu lưu

-- Phim 3 (Avengers) thuộc Viễn tưởng (3), Hành động (1)
INSERT INTO Phim_TheLoai (MaPhim, MaTL) VALUES
(3, 3), -- Viễn tưởng
(3, 1); -- Hành động

-- PHÒNG
INSERT INTO Phong(TenPhong, SoCho) VALUES
(N'Phòng 1', 20),
(N'Phòng 2', 30);

-- GHẾ PHÒNG 1 (A1–A20)
INSERT INTO Ghe(MaPhong, ViTri) VALUES
(1, 'A1'), (1, 'A2'), (1, 'A3'), (1, 'A4'), (1, 'A5'),
(1, 'A6'), (1, 'A7'), (1, 'A8'), (1, 'A9'), (1, 'A10'),
(1, 'A11'), (1, 'A12'), (1, 'A13'), (1, 'A14'), (1, 'A15'),
(1, 'A16'), (1, 'A17'), (1, 'A18'), (1, 'A19'), (1, 'A20');


-- GHẾ PHÒNG 2 (B1–B30)
INSERT INTO Ghe(MaPhong, ViTri) VALUES
(2, 'B1'), (2, 'B2'), (2, 'B3'), (2, 'B4'), (2, 'B5'),
(2, 'B6'), (2, 'B7'), (2, 'B8'), (2, 'B9'), (2, 'B10'),
(2, 'B11'), (2, 'B12'), (2, 'B13'), (2, 'B14'), (2, 'B15'),
(2, 'B16'), (2, 'B17'), (2, 'B18'), (2, 'B19'), (2, 'B20'),
(2, 'B21'), (2, 'B22'), (2, 'B23'), (2, 'B24'), (2, 'B25'),
(2, 'B26'), (2, 'B27'), (2, 'B28'), (2, 'B29'), (2, 'B30');

-- SUẤT CHIẾU 
INSERT INTO SuatChieu(MaPhim, MaPhong, NgayChieu, GioChieu, GiaVe) VALUES
(1, 1, '2025-12-15', '19:00', 120000),
(2, 1, '2025-12-15', '14:00', 80000),
(3, 2, '2025-12-20', '20:00', 150000);
INSERT INTO SuatChieu(MaPhim, MaPhong, NgayChieu, GioChieu, GiaVe) VALUES
(1, 1, '2025-12-03', '19:00', 120000), -- Chiếu hôm nay (03/12) lúc 19h
(2, 1, '2025-12-03', '14:00', 80000),  -- Chiếu hôm nay (03/12) lúc 14h
(3, 2, '2025-12-04', '20:00', 150000), -- Chiếu ngày mai (04/12) lúc 20h
(1, 2, '2025-12-04', '09:00', 120000); -- Thêm 1 suất sáng ngày mai
-- DỊCH VỤ
INSERT INTO DichVu(TenDV, Gia) VALUES
(N'Bắp rang bơ', 60000),
(N'Nước ngọt', 35000),
(N'Combo bắp + nước', 90000),
(N'Hotdog', 45000);

-- KHUYẾN MÃI
INSERT INTO KhuyenMai(TenKM, DoiTuong, TiLeGiam) VALUES
(N'Giảm 20% cho học sinh', 'HocSinh', 0.20),
(N'Giảm 15% cho sinh viên', 'SinhVien', 0.15);

-- ĐẶT VÉ (Sinh viên đặt Avengers)
INSERT INTO DatVe(MaKH, MaSC) VALUES (2, 3);
DECLARE @MaDat INT = SCOPE_IDENTITY();

-- Ghế B5 + B6
INSERT INTO Ve(MaDatVe, MaGhe, GiaVe) VALUES
(@MaDat, 25, 150000),
(@MaDat, 26, 150000);

-- Mua dịch vụ
INSERT INTO HoaDonDichVu(MaKH, MaDV, SoLuong, MaDatVe) VALUES
(2, 3, 1, @MaDat),
(2, 2, 2, @MaDat);


SELECT MaHDDV, MaKH, MaDV, SoLuong, NgayMua, MaDatVe 
FROM HoaDonDichVu 
ORDER BY MaHDDV DESC;

-- 1. Xóa sạch dữ liệu bảng con trước (Tránh lỗi khóa ngoại)
DELETE FROM HoaDonDichVu;
DELETE FROM Ve;

-- 2. Xóa sạch dữ liệu bảng cha
DELETE FROM DatVe;

-- 3. Reset bộ đếm số tự động (IDENTITY) về 0
-- Để đơn vé tiếp theo bạn tạo sẽ bắt đầu lại là số 1
DBCC CHECKIDENT ('HoaDonDichVu', RESEED, 0);
DBCC CHECKIDENT ('Ve', RESEED, 0);
DBCC CHECKIDENT ('DatVe', RESEED, 0);