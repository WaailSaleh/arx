const express = require('express');
const multer = require('multer');
const archiver = require('archiver');
const decompress = require('decompress');
const cors = require('cors');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);
const app = express();
const port = 8213;

// Enable CORS and JSON parsing
app.use(cors());
app.use(express.json());

// Configure multer for file uploads
const upload = multer({
    dest: '/tmp/uploads/',
    limits: {
        fileSize: 100 * 1024 * 1024 // 100MB limit
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'application/zip' || file.originalname.endsWith('.zip')) {
            cb(null, true);
        } else {
            cb(new Error('Only .zip files are allowed'), false);
        }
    }
});

// Paths configuration
const SAVE_GAMES_PATH = '/palworld-data/Pal/Saved/SaveGames';
const BACKUP_PATH = '/tmp/backups';
const DOCKER_CONTAINER = 'palworld-server';
const DOCKER_SERVICE = 'palworld';

// Ensure directories exist
fs.ensureDirSync(BACKUP_PATH);

// Utility function to execute Docker commands from host
async function executeDockerCommand(command) {
    try {
        // Execute docker compose command from host via docker socket
        const { stdout, stderr } = await execAsync(`docker exec ${DOCKER_CONTAINER} ${command}`);
        return { success: true, stdout, stderr };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Alternative backup using direct file copy instead of docker command
async function createFileBackup() {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupFileName = `palworld-backup-${timestamp}.zip`;
    const backupFilePath = path.join(BACKUP_PATH, backupFileName);
    
    try {
        // Check if save directory exists and has content
        if (await fs.pathExists(SAVE_GAMES_PATH)) {
            const saveContents = await fs.readdir(SAVE_GAMES_PATH);
            if (saveContents.length === 0) {
                return { 
                    success: true, 
                    message: 'No existing save to backup (empty save directory)',
                    isEmpty: true 
                };
            }
            
            // Create backup archive
            const archive = archiver('zip', { zlib: { level: 9 } });
            const output = fs.createWriteStream(backupFilePath);
            
            return new Promise((resolve, reject) => {
                output.on('close', () => {
                    resolve({
                        success: true,
                        backupFile: backupFileName,
                        size: archive.pointer(),
                        isEmpty: false
                    });
                });
                
                archive.on('error', reject);
                archive.pipe(output);
                archive.directory(SAVE_GAMES_PATH, false);
                archive.finalize();
            });
        } else {
            return { 
                success: true, 
                message: 'No existing save directory to backup (fresh server)',
                isEmpty: true 
            };
        }
    } catch (error) {
        throw new Error(`File backup failed: ${error.message}`);
    }
}

// PWA-103: Automatic backup before save upload
async function createBackup() {
    try {
        // Use file-based backup instead of docker command
        return await createFileBackup();
    } catch (error) {
        throw new Error(`Backup failed: ${error.message}`);
    }
}

// PWA-201: Download current world save
app.get('/api/v1/saves/download', async (req, res) => {
    try {
        const timestamp = new Date().toISOString().split('T')[0];
        const fileName = `palworld-save-backup-${timestamp}.zip`;
        
        // Check if save directory exists
        if (!await fs.pathExists(SAVE_GAMES_PATH)) {
            return res.status(404).json({
                error: 'No save games found',
                message: 'The save games directory does not exist'
            });
        }
        
        // Set response headers
        res.setHeader('Content-Type', 'application/zip');
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        
        // Create zip archive and stream it directly
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        archive.on('error', (err) => {
            console.error('Archive error:', err);
            if (!res.headersSent) {
                res.status(500).json({ error: 'Failed to create archive' });
            }
        });
        
        // Pipe archive data to response
        archive.pipe(res);
        
        // Add the save games directory to the archive
        archive.directory(SAVE_GAMES_PATH, false);
        
        // Finalize the archive
        await archive.finalize();
        
    } catch (error) {
        console.error('Download error:', error);
        if (!res.headersSent) {
            res.status(500).json({
                error: 'Download failed',
                message: error.message
            });
        }
    }
});

// PWA-101: Upload save file
app.post('/api/v1/saves/upload', upload.single('saveFile'), async (req, res) => {
    let tempExtractPath = null;
    
    try {
        if (!req.file) {
            return res.status(400).json({
                error: 'No file uploaded',
                message: 'Please select a .zip file to upload'
            });
        }
        
        console.log('Starting save upload process...');
        
        // Step 1: Create backup (PWA-103)
        console.log('Creating backup...');
        let backupResult;
        try {
            backupResult = await createBackup();
            console.log('Backup created:', backupResult);
        } catch (backupError) {
            console.error('Backup failed:', backupError);
            return res.status(500).json({
                error: 'Backup failed',
                message: `Cannot proceed with upload: ${backupError.message}`
            });
        }
        
        // Step 2: Extract uploaded file
        tempExtractPath = `/tmp/extract-${Date.now()}`;
        await fs.ensureDir(tempExtractPath);
        
        console.log('Extracting uploaded file...');
        await decompress(req.file.path, tempExtractPath);
        
        // Step 3: Validate extracted content
        const extractedContents = await fs.readdir(tempExtractPath);
        console.log('Extracted contents:', extractedContents);
        
        // Step 4: Replace save files and restart server
        console.log('Clearing existing save directory...');
        if (await fs.pathExists(SAVE_GAMES_PATH)) {
            await fs.emptyDir(SAVE_GAMES_PATH);
        } else {
            await fs.ensureDir(SAVE_GAMES_PATH);
        }
        
        console.log('Copying new save files...');
        await fs.copy(tempExtractPath, SAVE_GAMES_PATH);
        
        console.log('Restarting Palworld server...');
        // Use docker compose restart from the host system with correct service name
        const restartResult = await execAsync(`cd /opt/palworld && docker compose restart ${DOCKER_SERVICE}`);
        
        // Clean up uploaded file
        await fs.remove(req.file.path);
        
        res.json({
            success: true,
            message: 'Save uploaded successfully! Server is restarting.',
            details: {
                uploadedFile: req.file.originalname,
                extractedFiles: extractedContents.length,
                serverRestarted: true,
                backupSkipped: backupResult.isEmpty
            }
        });
        
    } catch (error) {
        console.error('Upload error:', error);
        
        // Clean up on error
        if (req.file) {
            await fs.remove(req.file.path).catch(() => {});
        }
        
        res.status(500).json({
            error: 'Upload failed',
            message: error.message
        });
    } finally {
        // Clean up temp extraction directory
        if (tempExtractPath) {
            await fs.remove(tempExtractPath).catch(() => {});
        }
    }
});

// Health check endpoint
app.get('/api/v1/saves/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'palworld-save-api',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((error, req, res, next) => {
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                error: 'File too large',
                message: 'Save file must be smaller than 100MB'
            });
        }
    }
    
    res.status(500).json({
        error: 'Server error',
        message: error.message
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Palworld Save API listening on port ${port}`);
    console.log(`Health check: http://localhost:${port}/api/v1/health`);
});
